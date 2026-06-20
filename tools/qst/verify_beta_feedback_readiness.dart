import 'dart:io';

const feedbackPlanPath = 'docs/qst/BETA_FEEDBACK.yaml';
const operationsDocPath = 'docs/product/beta_feedback_operations.md';

const requiredPlanSnippets = [
  'intake_channels:',
  'required_fields:',
  'severity:',
  'surface:',
  'feedback_type:',
  'triage_rules:',
  'qst_conversion:',
  'S0:',
  'S1:',
  'S2:',
  'S3:',
  'next_id_policy:',
];

const requiredDocSnippets = [
  'Beta Feedback Operations',
  'Intake',
  'Triage Rhythm',
  'Conversion To QST',
  'Beta Stop Conditions',
  'Launch Readiness Signal',
  'Quest -> Mission -> Trail',
  'navigator/companion',
];

void main() {
  final failures = <String>[];
  _checkFile(feedbackPlanPath, requiredPlanSnippets, failures);
  _checkFile(operationsDocPath, requiredDocSnippets, failures);

  if (failures.isNotEmpty) {
    stderr.writeln('Beta feedback readiness verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta feedback readiness verification passed.');
  stdout.writeln('Checked feedback plan and operations guide.');
}

void _checkFile(String path, List<String> snippets, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing required file: $path');
    return;
  }

  final content = file.readAsStringSync();
  for (final snippet in snippets) {
    if (!content.contains(snippet)) {
      failures.add('Missing "$snippet" in $path');
    }
  }
}
