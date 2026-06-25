#!/usr/bin/env bash

# ===== Persistent Storage Setup =====
PERSIST_DIR="/data"
mkdir -p $PERSIST_DIR/{tailscale,home,root,opt}

# Make /root persistent (zsh config, ssh keys, etc.)
if [ ! -L /root ]; then
  echo "Setting up persistent /root..."
  cp -an /root/. $PERSIST_DIR/root/ 2>/dev/null || true
  rm -rf /root && ln -sf $PERSIST_DIR/root /root
fi

# Make /opt persistent (spaceship prompt, zsh plugins, etc.)
if [ ! -L /opt ]; then
  echo "Setting up persistent /opt..."
  cp -an /opt/. $PERSIST_DIR/opt/ 2>/dev/null || true
  rm -rf /opt && ln -sf $PERSIST_DIR/opt /opt
fi

# Make /home persistent
if [ ! -L /home ]; then
  echo "Setting up persistent /home..."
  cp -an /home/. $PERSIST_DIR/home/ 2>/dev/null || true
  rm -rf /home && ln -sf $PERSIST_DIR/home /home
fi

export TS_STATE_DIR=$PERSIST_DIR/tailscale

# ===== Start Tailscale =====
/render/tailscaled \
  --tun=userspace-networking \
  --socks5-server=localhost:1055 \
  --state=$TS_STATE_DIR/tailscaled.state &
PID=$!

ADVERTISE_ROUTES=${ADVERTISE_ROUTES:-10.0.0.0/8}
TS_EXTRA_ARGS=${TS_EXTRA_ARGS:-""}

until /render/tailscale up \
  --authkey="${TAILSCALE_AUTHKEY}" \
  --hostname="${RENDER_SERVICE_NAME:-render-tailscale}" \
  --advertise-routes="$ADVERTISE_ROUTES" \
  ${TS_EXTRA_ARGS}; do
  sleep 0.1
done

tailscale_ip=$(/render/tailscale ip)
echo "Tailscale is up at IP ${tailscale_ip}"

# ===== Health Check Server (so Render marks deploy as Live) =====
echo "Starting health check server on port ${PORT:-10000}..."
while true; do
  printf "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: text/plain\r\n\r\nok" | nc -l -p "${PORT:-10000}" -q 1 > /dev/null 2>&1
done &

wait ${PID}
