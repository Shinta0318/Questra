#!/usr/bin/env bash
set -euo pipefail

adb wait-for-device
adb shell cmd package list packages >/dev/null
adb shell df /data

cd "$GITHUB_WORKSPACE/apps/mobile"
flutter test integration_test/qst_283_candidate_journey_test.dart -d emulator-5554 --no-pub
