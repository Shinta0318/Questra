import 'dart:io';

const reportPath = 'docs/product/beta_readiness_report.md';

const requiredSnippets = [
  'Beta Launch Readiness Report',
  'NO-GO for tester distribution',
  '66 / 100',
  'Automated Evidence',
  'Open P0 Blockers',
  'BLK-001 Supabase Project Evidence',
  'BLK-005 Legal Sign-Off',
  'Recommended QSTs',
  'QST-159 Beta Candidate Manifest Automation',
  'QST-167 Beta Go-Live Review',
  'Technical Beta Candidate',
  'Operational Beta',
];

const forbiddenSnippets = [
  'Release Manager readiness: 74 / 100',
  'Release Manager blocking issues: 0',
  'MVP prepared rate: 93%',
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
