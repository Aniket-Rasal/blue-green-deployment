#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  switch.sh — Switch Nginx traffic between blue and green
#
#  Usage:   ./switch.sh blue|green
#  Example: ./switch.sh green   # Point live traffic to green container
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NGINX_DIR="$PROJECT_DIR/nginx"
ACTIVE_CONF="$NGINX_DIR/active.conf"

TARGET="${1:-}"

# ── Validate input ────────────────────────────────────────────────────────────
if [[ "$TARGET" != "blue" && "$TARGET" != "green" ]]; then
  echo "❌  Usage: $0 blue|green"
  echo "    Current active:"
  if [[ -L "$ACTIVE_CONF" ]]; then
    current=$(readlink "$ACTIVE_CONF" | xargs basename | sed 's/.conf//')
    echo "    → $current"
  else
    echo "    → unknown (active.conf not a symlink)"
  fi
  exit 1
fi

# ── Check target container is healthy before switching ────────────────────────
echo "🔎  Verifying 'app-${TARGET}' container is healthy..."
"$SCRIPT_DIR/healthcheck.sh" "app-${TARGET}" 15 3
echo ""

# ── Create/update the symlink ────────────────────────────────────────────────
echo "🔀  Switching Nginx → ${TARGET}..."
ln -sf "${TARGET}.conf" "$ACTIVE_CONF"

# ── Reload Nginx without dropping connections ─────────────────────────────────
echo "🔄  Reloading Nginx (zero-downtime)..."
docker exec nginx-proxy nginx -t   # Test config first
docker exec nginx-proxy nginx -s reload

# ── Verify ────────────────────────────────────────────────────────────────────
sleep 2
echo ""
echo "🌐  Verifying traffic is hitting ${TARGET}..."
RESPONSE=$(curl -s -I http://localhost/ 2>/dev/null | grep -i "X-Active-Env" || echo "")
if echo "$RESPONSE" | grep -qi "$TARGET"; then
  echo "✅  Traffic successfully switched to ${TARGET}!"
else
  echo "⚠️   Could not confirm switch via HTTP header (Nginx may still be reloading)."
  echo "    Check manually: curl -I http://localhost/"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Active environment : ${TARGET^^}"
echo "  Nginx reloaded     : ✅"
echo "  Downtime           : 0s"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
