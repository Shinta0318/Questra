import 'dart:io';

const requiredFiles = {
  'docs/QUESTRA_MASTER_SPEC_V2.md': ['200%文字', '日本語IME', '44px以上', 'Semantics'],
  'docs/product/DESIGN_BIBLE_V2.md': [
    'FittedBox.scaleDown',
    '44px touch targets',
    'Japanese IME',
    'Today Focus contract',
  ],
  'apps/mobile/test/arc_chat_keyboard_test.dart': ['Japanese IME composition'],
  'apps/mobile/test/bottom_navigation_v2_test.dart': [
    'bottom navigation exposes every destination',
  ],
  'apps/mobile/test/responsive_viewport_matrix_test.dart': ['320'],
};

const forbiddenPatterns = {
  'apps/mobile/lib': ['FittedBox(', 'BoxFit.scaleDown', 'AutoSizeText('],
};

void main(List<String> args) {
  final requirePhysicalEvidence = args.contains('--require-physical-evidence');
  final failures = <String>[];

  for (final entry in requiredFiles.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) {
      failures.add('Missing required accessibility file: ${entry.key}');
      continue;
    }
    final content = file.readAsStringSync();
    for (final token in entry.value) {
      if (!content.contains(token)) {
        failures.add('${entry.key} is missing required token: $token');
      }
    }
  }

  for (final entry in forbiddenPatterns.entries) {
    final root = Directory(entry.key);
    if (!root.existsSync()) continue;
    for (final file
        in root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final content = file.readAsStringSync();
      for (final pattern in entry.value) {
        if (content.contains(pattern)) {
          failures.add(
            '${file.path} contains forbidden accessibility pattern: $pattern',
          );
        }
      }
    }
  }

  if (requirePhysicalEvidence) {
    final result = Process.runSync(Platform.resolvedExecutable, [
      'run',
      'tools/qst/verify_physical_accessibility_evidence.dart',
      '--require-physical',
    ]);
    if (result.exitCode != 0) {
      failures.add(
        'Physical accessibility evidence failed: ${(result.stderr as String).trim()}',
      );
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Accessibility release gate failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    requirePhysicalEvidence
        ? 'Accessibility release gate passed with physical evidence.'
        : 'Accessibility release gate passed for local static contracts.',
  );
}
