#!/usr/bin/env bash

# ===== Persistent Storage Setup =====
PERSIST_DIR="/data"
mkdir -p $PERSIST_DIR/{tailscale,home,root}

# Make /root persistent (zsh config, ssh keys, etc.)
if [ ! -L /root ]; then
  echo "Setting up persistent /root..."
  cp -an /root/. $PERSIST_DIR/root/ 2>/dev/null || true
  rm -rf /root && ln -sf $PERSIST_DIR/root /root
fi

# Make /home persistent
if [ ! -L /home ]; then
  echo "Setting up persistent /home..."
  cp -an /home/. $PERSIST_DIR/home/ 2>/dev/null || true
  rm -rf /home && ln -sf $PERSIST_DIR/home /home
fi

# ===== Restore Tailscale state from env var (free-tier workaround) =====
# Render free tier doesn't support persistent disks, so each deploy wipes /data.
# To keep the same Tailscale node identity across deploys, the state file
# is stored in a base64-encoded env var and restored here.
if [ -n "$TAILSCALE_STATE_BASE64" ]; then
  echo "Restoring Tailscale state from TAILSCALE_STATE_BASE64..."
  # Decode and validate it's real JSON before writing
  DECODED=$(echo "$TAILSCALE_STATE_BASE64" | base64 -d 2>/dev/null) || true
  if echo "$DECODED" | head -c1 | grep -q '{' 2>/dev/null; then
    echo "$DECODED" > $PERSIST_DIR/tailscale/tailscaled.state
    echo "State restored successfully."
  else
    echo "WARNING: TAILSCALE_STATE_BASE64 does not contain valid JSON (starts with '$(echo "$DECODED" | head -c20)'). Skipping restore."
    echo "The env var may be corrupted or truncated. Clear it and do a fresh deploy to generate a new one."
  fi
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

# ===== Capture Tailscale state for future deploys (first run only) =====
if [ -z "$TAILSCALE_STATE_BASE64" ] && [ -f "$PERSIST_DIR/tailscale/tailscaled.state" ]; then
  STATE_B64=$(base64 -w0 < "$PERSIST_DIR/tailscale/tailscaled.state")
  # Save to a known file so you can cat/copy it via SSH
  STATE_FILE="$PERSIST_DIR/tailscale/state.base64"
  echo "$STATE_B64" > "$STATE_FILE"
  echo ""
  echo "===================================================================="
  echo "  Tailscale state saved to $STATE_FILE"
  echo "  (SSH in and run: cat $STATE_FILE)"
  echo ""
  echo "  To keep the same node across future deploys, save this as a"
  echo "  Render secret env var named TAILSCALE_STATE_BASE64:"
  echo "===================================================================="
  echo "$STATE_B64"
  echo "===================================================================="
  echo ""
fi

# ===== Health Check Server (so Render marks deploy as Live) =====
echo "Starting health check server on port ${PORT:-10000}..."
while true; do
  printf "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: text/plain\r\n\r\nok" | nc -l -p "${PORT:-10000}" -q 1 > /dev/null 2>&1
done &

wait ${PID}
