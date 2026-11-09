#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 -c 'import sys; sys.path.insert(0, "scripts"); from desktop_preview import run_tests; run_tests()'
python3 -m unittest discover -s Tests/InstallerTests -p 'test_desktop_preview*.py' -v
