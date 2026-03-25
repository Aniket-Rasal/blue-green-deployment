#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  healthcheck.sh — Poll a container's /health endpoint until it's ready
#
#  Usage: ./healthcheck.sh <container_name> [max_retries] [interval_seconds]
#  Returns: 0 on success, 1 on failure
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

CONTAINER="${1:-}"
MAX_RETRIES="${2:-20}"
INTERVAL="${3:-3}"

if [[ -z "$CONTAINER" ]]; then
  echo "❌  Usage: $0 <container_name> [max_retries] [interval]"
  exit 1
fi

echo "🔍  Waiting for container '$CONTAINER' to become healthy..."
echo "    (max ${MAX_RETRIES} retries, ${INTERVAL}s apart)"

for i in $(seq 1 "$MAX_RETRIES"); do
  # Check Docker health status first
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "not-found")

  case "$STATUS" in
    healthy)
      echo "✅  Container '$CONTAINER' is healthy! (attempt $i/${MAX_RETRIES})"
      exit 0
      ;;
    starting)
      echo "⏳  Attempt $i/${MAX_RETRIES}: still starting..."
      ;;
    unhealthy)
      echo "❌  Container '$CONTAINER' is unhealthy!"
      echo "    Last logs:"
      docker logs --tail 20 "$CONTAINER" 2>&1 || true
      exit 1
      ;;
    not-found)
      echo "❌  Container '$CONTAINER' not found."
      exit 1
      ;;
    *)
      # Fallback: try HTTP health endpoint directly
      HTTP_STATUS=$(docker exec "$CONTAINER" \
        wget -qO- http://localhost:3000/health 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || echo "")
      if [[ "$HTTP_STATUS" == "healthy" ]]; then
        echo "✅  Container '$CONTAINER' responded healthy via HTTP! (attempt $i/${MAX_RETRIES})"
        exit 0
      fi
      echo "⏳  Attempt $i/${MAX_RETRIES}: status='$STATUS', waiting..."
      ;;
  esac

  sleep "$INTERVAL"
done

echo "❌  Container '$CONTAINER' did not become healthy after $MAX_RETRIES attempts."
echo "    Dumping recent logs:"
docker logs --tail 30 "$CONTAINER" 2>&1 || true
exit 1
