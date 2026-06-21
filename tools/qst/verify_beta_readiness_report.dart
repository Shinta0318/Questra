import 'dart:io';

const reportPath = 'docs/product/beta_readiness_report.md';

const requiredSnippets = [
  'Release Manager readiness: 74 / 100',
  'MVP prepared rate: 93%',
  'Performance readiness check: passed',
  'Beta feedback operations: ready',
  'Arc Experience Epic: completed for internal beta',
  'QST-067: Performance Measurement Pass',
  'QST-069: Beta Feedback Operations',
  'not public release ready',
  'real-device beta validation',
];

const forbiddenSnippets = [
  'Performance targets are documented but not measured by repeatable tooling.',
  'Arc Experience Epic QST-047 through QST-059 should be completed',
];

void main() {
  final failures = <String>[];
  final report = File(reportPath);
  if (!report.existsSync()) {
    failures.add('Missing beta readiness report: $reportPath');
  } else {
    final content = report.readAsStringSync();
    for (final snippet in requiredSnippets) {
      if (!content.contains(snippet)) {
        failures.add('Missing "$snippet" in $reportPath');
      }
    }
    for (final snippet in forbiddenSnippets) {
      if (content.contains(snippet)) {
        failures.add('Outdated readiness statement remains: "$snippet"');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Beta readiness report verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta readiness report verification passed.');
}
