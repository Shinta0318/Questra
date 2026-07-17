import 'dart:io';

const planPath = 'docs/product/beta_crash_error_capture_plan.md';
const feedbackPath = 'docs/qst/BETA_FEEDBACK.yaml';

const requiredPlanSnippets = [
  'Current Audit',
  'Event Taxonomy',
  'Minimum Evidence Schema',
  'Prohibited Data',
  'Capture Boundaries',
  'Severity and Response',
  'Storage, Access, and Retention',
  'Verification Matrix',
  'QST-127',
];

const requiredFeedbackSnippets = [
  'error_capture:',
  'status: prepared',
  'event_types:',
  'required_evidence:',
  'prohibited_payloads:',
  'retention_days: 30',
  'privacy_gate: QST-127',
];

void main() {
  final failures = <String>[];
  _checkFile(planPath, requiredPlanSnippets, failures);
  _checkFile(feedbackPath, requiredFeedbackSnippets, failures);

  if (failures.isNotEmpty) {
    stderr.writeln('Beta error capture readiness verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta error capture readiness verification passed.');
  stdout.writeln(
    'Checked evidence contract, privacy boundary, and response plan.',
  );
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
