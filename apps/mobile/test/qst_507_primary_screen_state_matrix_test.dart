import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root =
      Directory.current.path.endsWith('apps${Platform.pathSeparator}mobile')
      ? '../..'
      : '.';
  final matrix = File('$root/docs/qst/PRIMARY_SCREEN_STATE_MATRIX.yaml');
  final guide = File('$root/docs/product/SCREEN_STATE_MATRIX_V1.md');
  final verifier = File(
    '$root/tools/qst/verify_primary_screen_state_matrix.dart',
  );

  test('matrix covers every primary journey surface', () {
    final source = matrix.readAsStringSync();
    for (final screen in const [
      'home',
      'arc',
      'quest',
      'trail',
      'profile',
      'onboarding',
    ]) {
      expect(source, contains('  - id: $screen\n'));
    }
    expect(source, contains('physical_evidence_replaced_by_golden: false'));
  });

  test('screen guide separates widget, golden, and physical evidence', () {
    final source = guide.readAsStringSync();
    expect(source, contains('widget_verified'));
    expect(source, contains('golden_verified'));
    expect(source, contains('physical_verified'));
    expect(source, contains('AI fallbackで固定Missionを捏造しない'));
  });

  test('matrix verifier fails closed on missing screens or evidence', () {
    final source = verifier.readAsStringSync();
    expect(source, contains('Missing screen:'));
    expect(source, contains('Missing test evidence:'));
    expect(source, contains('exitCode = 1'));
  });
}
