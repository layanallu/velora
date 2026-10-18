#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift compiler required (Xcode command line tools)."
  exit 1
fi
MATCHER_BIN="$(mktemp -t velora-speech.XXXXXX)"
TOPIC_BIN="$(mktemp -t velora-content.XXXXXX)"
trap 'rm -f "$MATCHER_BIN" "$TOPIC_BIN"' EXIT
swiftc Velora/Core/Audio/SpeechWordMatcher.swift QualityChecks/SpeechWordMatcherTests.swift -o "$MATCHER_BIN"
"$MATCHER_BIN"
swiftc Velora/Models/TopicLibrary.swift QualityChecks/TopicContentTests.swift -o "$TOPIC_BIN"
"$TOPIC_BIN"
