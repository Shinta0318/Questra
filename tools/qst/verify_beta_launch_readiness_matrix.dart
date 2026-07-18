import 'dart:io';

const matrixPath = 'docs/qst/BETA_LAUNCH_READINESS.yaml';

const requiredSnippets = [
  'decision: no_go',
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
  var score = 0;
  var maximum = 0;
  var blockerCount = 0;

  if (!file.existsSync()) {
    failures.add('Missing readiness matrix: $matrixPath');
  } else {
    final content = file.readAsStringSync();
    for (final snippet in requiredSnippets) {
      if (!content.contains(snippet)) {
        failures.add('Missing "$snippet" in $matrixPath');
      }
    }
    score = _integer(content, 'total', 2, failures);
    maximum = _integer(content, 'maximum', 2, failures);
    final earnedTotal = _integers(
      content,
      'earned',
      6,
    ).fold(0, (a, b) => a + b);
    final weightTotal = _integers(
      content,
      'weight',
      6,
    ).fold(0, (a, b) => a + b);
    if (score != earnedTotal) {
      failures.add(
        'Score total $score does not match earned dimensions $earnedTotal.',
      );
    }
    if (maximum != weightTotal) {
      failures.add(
        'Maximum $maximum does not match dimension weights $weightTotal.',
      );
    }
    blockerCount = RegExp(
      r'^  - id: BLK-',
      multiLine: true,
    ).allMatches(content).length;
    if (blockerCount != 5) {
      failures.add('Expected 5 P0 blockers, found $blockerCount.');
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
  stdout.writeln(
    'Decision: NO-GO, score: $score/$maximum, P0 blockers: $blockerCount.',
  );
}

int _integer(String content, String field, int indent, List<String> failures) {
  final values = _integers(content, field, indent);
  if (values.length != 1) {
    failures.add('Expected one $field value at indent $indent.');
    return 0;
  }
  return values.single;
}

List<int> _integers(String content, String field, int indent) {
  final prefix = ' ' * indent;
  return RegExp(
    '^${RegExp.escape(prefix + field)}:\\s*(\\d+)\\s*\$',
    multiLine: true,
  ).allMatches(content).map((match) => int.parse(match.group(1)!)).toList();
}
