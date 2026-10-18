#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v swiftc >/dev/null 2>&1; then
  echo 'Swift compiler not available. Run these checks on a Mac with Xcode.'
  exit 1
fi
OUTPUT="$(mktemp -t velora-onset-smoke.XXXXXX)"
trap 'rm -f "$OUTPUT"' EXIT
swiftc Velora/Core/Audio/OnsetAnalyzer.swift QualityChecks/OnsetAnalyzerSmoke.swift -o "$OUTPUT"
"$OUTPUT"
