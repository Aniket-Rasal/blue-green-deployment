#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  deploy.sh — Full Blue-Green deployment workflow
#
#  What this script does:
#   1. Detect which environment is currently LIVE (blue or green)
#   2. Determine the INACTIVE environment (the one to deploy to)
#   3. Build & start the new version in the inactive container
#   4. Run health checks against the new container
#   5. Switch Nginx traffic to the new container (zero downtime)
#   6. Optionally tear down the old container
#
#  Usage: ./deploy.sh [--version <tag>] [--keep-old] [--rollback]
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NGINX_DIR="$PROJECT_DIR/nginx"
ACTIVE_CONF="$NGINX_DIR/active.conf"

# ── Default flags ─────────────────────────────────────────────────────────────
VERSION_TAG="latest"
KEEP_OLD=false
ROLLBACK=false

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION_TAG="$2"; shift 2 ;;
    --keep-old) KEEP_OLD=true; shift ;;
    --rollback) ROLLBACK=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo "$(date '+%H:%M:%S') | $*"; }
info() { echo ""; echo "━━━ $* ━━━"; echo ""; }

# ── Detect current active environment ─────────────────────────────────────────
detect_active() {
  if [[ -L "$ACTIVE_CONF" ]]; then
    basename "$(readlink "$ACTIVE_CONF")" .conf
  else
    # Default: if no symlink exists yet, assume blue is active
    echo "blue"
  fi
}

CURRENT=$(detect_active)

if [[ "$ROLLBACK" == "true" ]]; then
  # Rollback: switch back to the other environment
  if [[ "$CURRENT" == "blue" ]]; then
    TARGET="green"
  else
    TARGET="blue"
  fi
  log "🔙  ROLLBACK requested — switching from ${CURRENT} back to ${TARGET}..."
  "$SCRIPT_DIR/switch.sh" "$TARGET"
  exit 0
fi

# ── Determine target ──────────────────────────────────────────────────────────
if [[ "$CURRENT" == "blue" ]]; then
  TARGET="green"
else
  TARGET="blue"
fi

info "🚀 Blue-Green Deploy Starting"
log "  Current LIVE : ${CURRENT^^}"
log "  Deploying TO : ${TARGET^^}"
log "  Version tag  : ${VERSION_TAG}"
echo ""

# ── Step 1: Build the new image ───────────────────────────────────────────────
info "Step 1 — Building ${TARGET} image"
cd "$PROJECT_DIR"

if [[ "$TARGET" == "green" ]]; then
  APP_DIR="./app/v2"
else
  APP_DIR="./app/v1"
fi

log "Building from $APP_DIR..."
docker build -t "app-${TARGET}:${VERSION_TAG}" "$APP_DIR"
log "✅  Image built: app-${TARGET}:${VERSION_TAG}"

# ── Step 2: Start (or restart) the inactive container ────────────────────────
info "Step 2 — Starting ${TARGET} container"

# Stop existing container if running
if docker ps -q -f name="app-${TARGET}" | grep -q .; then
  log "Stopping existing app-${TARGET} container..."
  docker stop "app-${TARGET}" || true
  docker rm   "app-${TARGET}" || true
fi

# Start the new container
log "Starting fresh app-${TARGET} container..."
docker run -d \
  --name "app-${TARGET}" \
  --network blue-green-deployment_app-network \
  --restart unless-stopped \
  -e PORT=3000 \
  -e NODE_ENV=production \
  --label "app.env=${TARGET}" \
  --label "app.version=${VERSION_TAG}" \
  "app-${TARGET}:${VERSION_TAG}"

log "✅  Container started"

# ── Step 3: Health check ──────────────────────────────────────────────────────
info "Step 3 — Health checking ${TARGET}"
"$SCRIPT_DIR/healthcheck.sh" "app-${TARGET}" 20 3

# ── Step 4: Switch traffic ────────────────────────────────────────────────────
info "Step 4 — Switching traffic"
"$SCRIPT_DIR/switch.sh" "$TARGET"

# ── Step 5: Keep or stop old container ────────────────────────────────────────
info "Step 5 — Cleanup"
if [[ "$KEEP_OLD" == "true" ]]; then
  log "⏸️   Keeping ${CURRENT} container running (instant rollback available)"
  log "    To rollback: ./scripts/deploy.sh --rollback"
else
  log "🧹  Stopping old ${CURRENT} container..."
  docker stop "app-${CURRENT}" 2>/dev/null && log "   Stopped app-${CURRENT}" || true
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          DEPLOYMENT SUCCESSFUL ✅              ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Previous env : ${CURRENT^^}                          "
echo "║  Live env now : ${TARGET^^}                           "
echo "║  Version      : ${VERSION_TAG}                        "
echo "║  Downtime     : 0s                             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
log "Visit http://localhost to verify the deployment."
