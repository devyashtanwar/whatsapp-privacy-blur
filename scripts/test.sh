#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/swift.sh run PrivacyCoreTests
python3 -m unittest discover -s Tests/InstallerTests -v
