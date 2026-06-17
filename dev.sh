#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Installing dependencies..."
npm ci

echo "==> Aggregating documentation from jEAP repos..."
bash scripts/clone-docs.sh
bash scripts/prepare-docs.sh

echo "==> Starting dev server with hot reload..."
npm start
