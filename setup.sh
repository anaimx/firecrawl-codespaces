#!/usr/bin/env bash
set -euo pipefail

FIRECRAWL_DIR="/workspaces/firecrawl"
FIRECRAWL_PORT=3663
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=== Firecrawl Codespace Setup ==="
echo ""

if [ ! -d "$FIRECRAWL_DIR" ]; then
    echo "[1/4] Cloning Firecrawl..."
    git clone --depth 1 https://github.com/mendableai/firecrawl.git "$FIRECRAWL_DIR"
else
    echo "[1/4] Firecrawl already cloned — skipping."
fi

cd "$FIRECRAWL_DIR"

if [ ! -f .env ]; then
    echo "[2/4] Creating .env (port ${FIRECRAWL_PORT}, no API keys)..."
    BULL_KEY=$(openssl rand -hex 16 2>/dev/null || echo "local-dev-key-change-me")
    cat > .env << EOF
PORT=${FIRECRAWL_PORT}
HOST=0.0.0.0
USE_DB_AUTHENTICATION=false
BULL_AUTH_KEY=${BULL_KEY}
EOF
else
    echo "[2/4] .env already exists — skipping."
fi

if [ -f "$SCRIPT_DIR/docker-compose.override.yaml" ]; then
    echo "[3/4] Copying docker-compose.override.yaml (pre-built images)..."
    cp "$SCRIPT_DIR/docker-compose.override.yaml" .
else
    echo "[3/4] No override file found — will build from source (slower first run)."
fi


echo "[4/4] Starting Firecrawl..."
docker compose pull 2>/dev/null || echo "  Pre-built images not found — building from source (this may take a few minutes)..."
docker compose up -d

echo ""
echo "Waiting for Firecrawl to be ready..."
READY=false
for i in $(seq 1 60); do
    if curl -sf "http://localhost:${FIRECRAWL_PORT}/" > /dev/null 2>&1; then
        READY=true
        break
    fi
    sleep 2
done

echo ""
if [ "$READY" = true ]; then
    echo "Firecrawl is running at http://localhost:${FIRECRAWL_PORT}"
else
    echo "Firecrawl didn't respond within 2 minutes."
    echo "The services may still be starting — check logs:"
    echo "  cd ${FIRECRAWL_DIR} && docker compose logs"
fi
