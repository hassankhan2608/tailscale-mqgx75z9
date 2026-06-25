#!/usr/bin/env bash

/render/tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
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

# Start a lightweight HTTP health server so Render marks the deploy as Live
# Render requires an open HTTP port on web services to complete deployment
echo "Starting health check server on port ${PORT:-10000}..."
while true; do
  echo -e "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: text/plain\r\n\r\nok" | nc -l -p "${PORT:-10000}" -q 1 > /dev/null 2>&1
done &

wait ${PID}
