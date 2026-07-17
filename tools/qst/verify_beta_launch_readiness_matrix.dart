import 'dart:io';

const matrixPath = 'docs/qst/BETA_LAUNCH_READINESS.yaml';

const requiredSnippets = [
  'decision: no_go',
  'total: 66',
  'maximum: 100',
  'automated_gates:',
  'flutter_tests: passed_219',
  'p0_blockers:',
  'BLK-001',
  'BLK-002',
  'BLK-003',
  'BLK-004',
  'BLK-005',
  'QST-159',
  'QST-167',
  'required_sign_offs:',
];

void main() {
  final file = File(matrixPath);
  final failures = <String>[];

  if (!file.existsSync()) {
    failures.add('Missing readiness matrix: $matrixPath');
  } else {
    final content = file.readAsStringSync();
    for (final snippet in requiredSnippets) {
      if (!content.contains(snippet)) {
        failures.add('Missing "$snippet" in $matrixPath');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Beta launch readiness matrix verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta launch readiness matrix verification passed.');
  stdout.writeln('Decision: NO-GO, score: 66/100, P0 blockers: 5.');
}
