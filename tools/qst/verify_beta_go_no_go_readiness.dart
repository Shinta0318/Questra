import 'dart:io';

const checklistPath = 'docs/product/beta_go_no_go_checklist.md';

const requiredSnippets = [
  'Current Decision',
  'NO-GO: evidence incomplete',
  'Candidate Identity',
  'Automated Quality',
  'Supabase and Ownership',
  'Core Experience',
  'Device and Accessibility',
  'Trust, Privacy, and Operations',
  'Issue State',
  'GO Sign-Off',
  'Rollback Triggers',
  'Rollback Procedure',
  'Evidence Index',
  'Open S0 count',
  'Cross-account RLS',
  'Legal Reviewer',
];

void main() {
  final file = File(checklistPath);
  final failures = <String>[];

  if (!file.existsSync()) {
    failures.add('Missing required file: $checklistPath');
  } else {
    final content = file.readAsStringSync();
    for (final snippet in requiredSnippets) {
      if (!content.contains(snippet)) {
        failures.add('Missing "$snippet" in $checklistPath');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Beta Go/No-Go readiness verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta Go/No-Go readiness verification passed.');
  stdout.writeln('Checked gates, evidence, sign-off, and rollback procedure.');
}
