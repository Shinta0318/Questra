#!/usr/bin/env bash
set -euo pipefail

adb wait-for-device
for attempt in {1..30}; do
  if adb shell cmd package list packages >/dev/null 2>&1 \
    && adb shell cmd storage help >/dev/null 2>&1; then
    break
  fi
  if [[ "$attempt" -eq 30 ]]; then
    echo "Android package and storage services did not become ready." >&2
    exit 1
  fi
  sleep 2
done
adb shell df /data

cd "$GITHUB_WORKSPACE/apps/mobile"
timeout --signal=INT --kill-after=30s 20m \
  flutter test integration_test/qst_283_candidate_journey_test.dart \
    -d emulator-5554 \
    --no-pub
