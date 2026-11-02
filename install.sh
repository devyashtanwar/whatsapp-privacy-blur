#!/bin/bash
# Explicit install only: never requests root, alters OS protection, or launches the app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ "$EUID" -eq 0 ]]; then
    echo "Do not run this installer as root or with sudo." >&2
    exit 1
fi
if [[ "${1:-}" == "--help" ]]; then
    echo "Usage: ./install.sh [--replace]"
    echo "Installs the verified local build into ~/Applications, without launching it."
    exit 0
fi
INSTALL_ARGS=(--source "$ROOT/dist/WhatsApp Privacy Cover.app"
    --destination "$HOME/Applications/WhatsApp Privacy Cover.app")
if [[ "${1:-}" == "--replace" && "$#" -eq 1 ]]; then
    INSTALL_ARGS+=(--replace)
elif [[ "$#" -ne 0 ]]; then
    echo "Usage: ./install.sh [--replace]" >&2
    exit 1
fi
"$ROOT/build-app.sh"
python3 "$ROOT/scripts/verify_app.py" "$ROOT/dist/WhatsApp Privacy Cover.app"
python3 "$ROOT/scripts/install_bundle.py" "${INSTALL_ARGS[@]}"
