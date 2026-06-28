#!/bin/bash
# GTA VI Hub — auto-start script for macOS (run once, forget it)
# Start:  bash /Users/hbagent007/.openclaw/workspace/gta6-fansite/start-hub.sh
# Stop:   pkill -f "astro dev"; pkill -f cloudflared

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
SITE_DIR="/Users/hbagent007/.openclaw/workspace/gta6-fansite"
LOG_DIR="/tmp"

# Start Astro dev server
launchctl bootout gui/$(id -u)/com.gta6hub.site 2>/dev/null
launchctl bootstrap gui/$(id -u) /Users/hbagent007/Library/LaunchAgents/com.gta6hub.runner.plist 2>/dev/null

# Simple fallback: nohup
if ! curl -s -o /dev/null http://localhost:4321 2>/dev/null; then
  cd "$SITE_DIR"
  nohup npm run dev -- --host 0.0.0.0 --port 4321 > "$LOG_DIR/gta6hub-devserver.log" 2>&1 &
  sleep 5
fi

if ! pgrep -f cloudflared > /dev/null; then
  nohup cloudflared tunnel --url http://localhost:4321 > "$LOG_DIR/gta6hub-cf-tunnel.log" 2>&1 &
  sleep 8
fi

TUNNEL_URL=$(grep -o 'https://[a-z0-9.-]*\.trycloudflare\.com' "$LOG_DIR/gta6hub-cf-tunnel.log" | head -1)
echo "✅ GTA VI Hub is live at: $TUNNEL_URL"
echo "   Send this link to the artist!"
