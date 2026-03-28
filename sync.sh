#!/usr/bin/env bash
set -euo pipefail

echo "Syncing submodule URLs..."
git submodule sync --recursive

echo "Updating submodules to latest remote commits..."
git submodule update --init --remote --recursive

echo "Done. Current submodule status:"
git submodule status --recursive

git add .
git commit -m "script: Update submodules to latest commits"
