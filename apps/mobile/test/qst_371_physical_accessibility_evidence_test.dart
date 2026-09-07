import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final recorder = File(
    '../../tools/qst/record_physical_accessibility_evidence.dart',
  ).readAsStringSync();
  final verifier = File(
    '../../tools/qst/verify_physical_accessibility_evidence.dart',
  ).readAsStringSync();

  test(
    'physical evidence is candidate-bound, hashed, and privacy-reviewed',
    () {
      expect(recorder, contains("git', 'status', '--porcelain"));
      expect(recorder, contains('Candidate SHA does not match HEAD'));
      expect(recorder, contains('privacy review confirmation'));
      expect(recorder, contains('sha256:'));
      expect(recorder, contains("'ro.kernel.qemu'"));
      expect(recorder, contains('artifacts/qst376/'));
    },
  );

  test('emulator and missing artifacts cannot satisfy the physical gate', () {
    expect(verifier, contains('device_class: android_physical'));
    expect(verifier, contains('Exactly six physical evidence files'));
    expect(verifier, contains('Physical evidence hash changed'));
    expect(verifier, contains('emulator_is_physical_evidence: false'));
    expect(verifier, contains('artifacts/qst376/'));
  });

  test('asset package verifier binds evidence inventory to current HEAD', () {
    final packageVerifier = File(
      '../../tools/qst/verify_candidate_asset_package.dart',
    ).readAsStringSync();
    expect(packageVerifier, contains("git', 'rev-parse', 'HEAD"));
    expect(packageVerifier, contains('not bound to HEAD'));
  });
}
