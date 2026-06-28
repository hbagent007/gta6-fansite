#!/bin/bash
# GTA VI Hub — keeps both the dev server and tunnel running persistently

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
cd /Users/hbagent007/.openclaw/workspace/gta6-fansite || exit 1

# Start Astro dev server
/opt/homebrew/bin/npm run dev -- --host 0.0.0.0 --port 4321 > /tmp/gta6hub-devserver.log 2>&1 &
DEV_PID=$!

# Wait for dev server to be ready
for i in $(seq 1 15); do
  if curl -s -o /dev/null http://localhost:4321 2>/dev/null; then
    break
  fi
  sleep 1
done

# Start localtunnel via npx (handles subdomain better)
/opt/homebrew/bin/npx --yes localtunnel --port 4321 --subdomain gta6-hub-for-artist > /tmp/gta6hub-tunnel.log 2>&1 &
TUNNEL_PID=$!

# Monitor and restart if either dies
while true; do
  if ! kill -0 $DEV_PID 2>/dev/null; then
    /opt/homebrew/bin/npm run dev -- --host 0.0.0.0 --port 4321 > /tmp/gta6hub-devserver.log 2>&1 &
    DEV_PID=$!
    echo "[$(date)] Dev server restarted" >> /tmp/gta6hub-monitor.log
  fi
  if ! kill -0 $TUNNEL_PID 2>/dev/null; then
    /opt/homebrew/bin/npx --yes localtunnel --port 4321 --subdomain gta6-hub-for-artist > /tmp/gta6hub-tunnel.log 2>&1 &
    TUNNEL_PID=$!
    echo "[$(date)] Tunnel restarted" >> /tmp/gta6hub-monitor.log
  fi
  sleep 15
done
