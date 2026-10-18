#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_BIN="$(mktemp /tmp/velora-onset-evidence.XXXXXX)"
trap 'rm -f "$TMP_BIN"' EXIT
swiftc \
  "$ROOT/Velora/Core/Audio/OnsetAnalyzer.swift" \
  "$ROOT/Velora/Core/Audio/OnsetEvidenceStore.swift" \
  "$ROOT/QualityChecks/OnsetEvidenceStoreTests.swift" \
  -o "$TMP_BIN"
"$TMP_BIN"
