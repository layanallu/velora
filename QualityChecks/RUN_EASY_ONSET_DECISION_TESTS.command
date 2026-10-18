#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="$(mktemp -t velora-onset-decision.XXXXXX)"
trap 'rm -f "$BIN"' EXIT
swiftc Velora/Core/Audio/OnsetAnalyzer.swift Velora/Core/Audio/EasyOnsetAcceptance.swift QualityChecks/EasyOnsetAcceptanceTests.swift -o "$BIN"
"$BIN"
