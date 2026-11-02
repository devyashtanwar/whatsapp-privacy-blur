#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/swift.sh run PrivacyCoreTests
./scripts/swift.sh run TargetIdentityTests
export TARGET_IDENTITY_HARNESS="$(./scripts/swift.sh build --show-bin-path)/TargetIdentityTests"
python3 -m unittest discover -s Tests/InstallerTests -v
