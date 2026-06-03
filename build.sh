#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Installing dependencies..."
npm ci

echo "==> Building Docusaurus site..."
npm run build

echo ""
echo "✅ Build succeeded! Output is in the 'build/' directory."
echo ""
echo "To preview the site locally, run:"
echo "  npm run serve"
