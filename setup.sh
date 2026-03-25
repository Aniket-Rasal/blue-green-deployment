#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  setup.sh — First-time project setup
#  Run this once after cloning the repo.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_DIR="$SCRIPT_DIR/nginx"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║   Blue-Green Deployment — First Time Setup ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo "🔍  Checking prerequisites..."
command -v docker      >/dev/null 2>&1 || { echo "❌ Docker not found. Install: https://docs.docker.com/get-docker/"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || \
  docker compose version >/dev/null 2>&1 || { echo "❌ Docker Compose not found."; exit 1; }
echo "✅  Docker found: $(docker --version)"

# Make scripts executable
echo "🔐  Making scripts executable..."
chmod +x "$SCRIPT_DIR/scripts/"*.sh
echo "✅  Scripts ready"

# Create the initial symlink: blue is the default starting environment
echo "🔗  Setting initial active environment to BLUE..."
ln -sf "blue.conf" "$NGINX_DIR/active.conf"
echo "✅  nginx/active.conf → blue.conf"

# Start the blue container + nginx
echo ""
echo "🐳  Building and starting BLUE environment..."
docker compose up -d --build app-blue nginx
echo ""
echo "⏳  Waiting for blue to become healthy..."
sleep 5
"$SCRIPT_DIR/scripts/healthcheck.sh" "app-blue" 15 3

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║        Setup Complete! 🎉                   ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "  App (BLUE/v1)  : http://localhost"
echo ""
echo "  Next steps:"
echo "   • Deploy green : ./scripts/deploy.sh"
echo "   • Rollback     : ./scripts/deploy.sh --rollback"
echo "   • Switch only  : ./scripts/switch.sh green"
echo "   • Monitoring   : cd monitoring && docker compose -f docker-compose.monitoring.yml up -d"
echo ""
