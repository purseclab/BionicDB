#!/usr/bin/env bash
#
# deploy.sh — bring BionicDB up locally, starting from a fresh checkout.
#
# The libc object dataset (objects/<xx>/<sha256>.so) is large and is NOT tracked
# file-by-file in git (see objects/.gitignore). It ships compressed as
# objects.tar.xz. This script unpacks that archive and then builds and serves the
# API + web frontend with Docker, reusing the repo's Dockerfile / compose.yml.
#
# Usage:
#   ./deploy.sh                 # unpack dataset (if needed) and serve on :8000
#   BIONICDB_PORT=9000 ./deploy.sh
#   ./deploy.sh --unpack-only   # only unpack the dataset, do not start anything
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

ARCHIVE="objects.tar.xz"
PORT="${BIONICDB_PORT:-8000}"

log() { printf '[deploy] %s\n' "$*"; }

# --- 1. Unpack the libc object dataset (idempotent) -------------------------
# We exclude .gitignore so the repo's ignore rules are never overwritten.
if [ -n "$(find objects -name '*.so' -print -quit 2>/dev/null)" ]; then
    log "libc object dataset already unpacked ($(find objects -name '*.so' | wc -l | tr -d ' ') files)."
else
    if [ ! -f "$ARCHIVE" ]; then
        log "ERROR: $ARCHIVE not found in $REPO_ROOT." >&2
        exit 1
    fi
    log "Unpacking $ARCHIVE (this expands to ~150 MiB of libc objects)..."
    tar -xJf "$ARCHIVE" --exclude='*/.gitignore'
    log "Unpacked $(find objects -name '*.so' | wc -l | tr -d ' ') libc objects."
fi

if [ "${1:-}" = "--unpack-only" ]; then
    log "Dataset ready. Skipping server start (--unpack-only)."
    exit 0
fi

# --- 2. Build and serve -----------------------------------------------------
serve_url="http://localhost:${PORT}"
if docker compose version >/dev/null 2>&1; then
    log "Starting via 'docker compose' on ${serve_url} (frontend at /, API docs at /docs) ..."
    exec env BIONICDB_PORT="$PORT" docker compose up --build
elif command -v docker-compose >/dev/null 2>&1; then
    log "Starting via 'docker-compose' on ${serve_url} ..."
    exec env BIONICDB_PORT="$PORT" docker-compose up --build
elif command -v docker >/dev/null 2>&1; then
    log "docker compose not available; using plain 'docker' on ${serve_url} ..."
    docker build -t bionicdb .
    exec docker run --rm -p "${PORT}:8000" \
        -v "$REPO_ROOT/bionic.db:/app/bionic.db:ro" \
        -v "$REPO_ROOT/objects:/app/objects:ro" \
        bionicdb
else
    log "ERROR: Docker is not installed." >&2
    log "The dataset is unpacked, so you can run without Docker instead:" >&2
    log "    cd api && uv run uvicorn app.main:app --host 0.0.0.0 --port ${PORT}" >&2
    exit 1
fi
