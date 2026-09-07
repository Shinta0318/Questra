import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final recorder = File(
    '../../tools/qst/record_physical_accessibility_evidence.dart',
  ).readAsStringSync();
  final evidence = File(
    '../../docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml',
  ).readAsStringSync();

  test('recorder verifies a connected non-emulator Android device', () {
    expect(recorder, contains("'devices', '-l'"));
    expect(recorder, contains("'ro.kernel.qemu'"));
    expect(recorder, contains("startsWith('emulator-')"));
    expect(recorder, contains("'ro.product.model'"));
    expect(recorder, contains("'ro.build.version.release'"));
  });

  test('pending evidence remains explicit until a real session is recorded', () {
    expect(evidence, contains('qst: QST-376'));
    expect(evidence, contains('status: pending_physical_execution'));
    expect(evidence, contains('emulator_is_physical_evidence: false'));
  });
}
