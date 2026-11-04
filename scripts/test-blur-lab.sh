#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift run --package-path "$ROOT/Experiments/SelectiveBlurLab" \
  --scratch-path "$ROOT/.build/blur-lab" --cache-path "$ROOT/.build/lab-cache" \
  --config-path "$ROOT/.build/lab-config" --security-path "$ROOT/.build/lab-security" LabPolicyTests
swift run --package-path "$ROOT/Experiments/SelectiveBlurLab" \
  --scratch-path "$ROOT/.build/blur-lab" --cache-path "$ROOT/.build/lab-cache" \
  --config-path "$ROOT/.build/lab-config" --security-path "$ROOT/.build/lab-security" LabViewTests
