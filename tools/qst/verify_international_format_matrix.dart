import 'dart:io';

const _matrixPath = 'docs/product/international_format_matrix.md';
const _servicePath = 'apps/mobile/lib/core/i18n/locale_format_service.dart';
const _testPath = 'apps/mobile/test/qst_352_locale_format_service_test.dart';

void main() {
  final failures = <String>[];
  final matrix = _read(_matrixPath, failures);
  final service = _read(_servicePath, failures);
  final test = _read(_testPath, failures);

  _requireAll(matrix, _matrixPath, const [
    'ja-JP',
    'en-US',
    'en-GB',
    'RTL smoke',
    'AI Locale Rules',
    'English Beta is blocked until',
  ], failures);
  _requireAll(service, _servicePath, const [
    'formatMonth',
    'formatShortDate',
    'formatTime',
    'formatCurrency',
    'pluralMissionCount',
    "'GBP'",
    'isRtl',
  ], failures);
  _requireAll(test, _testPath, const [
    "QuestraLocaleFormatService('ja')",
    "QuestraLocaleFormatService('en_US')",
    "QuestraLocaleFormatService('en_GB')",
    "QuestraLocaleFormatService('ar')",
  ], failures);

  if (failures.isNotEmpty) {
    stderr.writeln('International format matrix verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('International format matrix verification passed.');
}

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing $path');
    return '';
  }
  return file.readAsStringSync();
}

void _requireAll(
  String content,
  String path,
  List<String> expected,
  List<String> failures,
) {
  for (final value in expected) {
    if (!content.contains(value)) {
      failures.add('$path must contain $value');
    }
  }
}
