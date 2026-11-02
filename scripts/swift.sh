#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/module-cache"
COMMAND="${1:?Expected a Swift package command}"
shift
exec swift "$COMMAND" --cache-path "$ROOT/.build/cache" --config-path "$ROOT/.build/config" --security-path "$ROOT/.build/security" "$@"
