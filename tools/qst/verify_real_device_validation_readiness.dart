import 'dart:io';

const validationDocPath = 'docs/product/real_device_beta_validation.md';

const requiredSnippets = [
  'Real Device Beta Validation',
  'Required Devices',
  'Preflight',
  'Manual Pass',
  'Stop Conditions',
  'Evidence To Capture',
  'Quest -> Mission -> Trail',
  'flutter analyze',
  'flutter test',
  'verify_rls_readiness.dart',
  'verify_performance_readiness.dart',
  'verify_beta_feedback_readiness.dart',
  'verify_beta_readiness_report.dart',
  'Arc Chat',
  'Arc Memory',
  'Navigator Rank',
  'Story appears as a product concept',
];

void main() {
  final failures = <String>[];
  final doc = File(validationDocPath);
  if (!doc.existsSync()) {
    failures.add('Missing validation guide: $validationDocPath');
  } else {
    final content = doc.readAsStringSync();
    for (final snippet in requiredSnippets) {
      if (!content.contains(snippet)) {
        failures.add('Missing "$snippet" in $validationDocPath');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Real-device validation readiness failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Real-device validation readiness passed.');
}
