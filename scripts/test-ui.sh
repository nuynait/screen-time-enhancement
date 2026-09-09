#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/generate.sh
simulator_id="$(python3 scripts/select-simulator.py "${1:-}")"
if [ "$#" -gt 0 ]; then shift; fi
xcodebuild -project ScreenTimeEnhancement.xcodeproj -scheme Gate -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath build/DerivedData \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test "$@"
