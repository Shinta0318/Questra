import 'dart:io';

const screenshotQaPath = 'docs/product/final_screenshot_qa.md';

const requiredSnippets = [
  'Final Screenshot QA',
  'Required Screens',
  'Home',
  'Quest Detail',
  'Mission',
  'Trail',
  'Guild',
  'Arc Chat',
  'Arc Memory',
  'Profile',
  'Media',
  'Viewports',
  '360 x 800',
  '390 x 844',
  '1280 x 800',
  'Pass Criteria',
  'reports/screenshots/<build-commit>/',
  'Stop Conditions',
  'Story appears',
  'AI assistant',
];

void main() {
  final failures = <String>[];
  final file = File(screenshotQaPath);
  if (!file.existsSync()) {
    failures.add('Missing screenshot QA guide: $screenshotQaPath');
  } else {
    final content = file.readAsStringSync();
    for (final snippet in requiredSnippets) {
      if (!content.contains(snippet)) {
        failures.add('Missing "$snippet" in $screenshotQaPath');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Screenshot QA readiness failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Screenshot QA readiness passed.');
}
