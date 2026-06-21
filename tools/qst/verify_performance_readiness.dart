import 'dart:io';

const approvedArcAssets = [
  'apps/mobile/assets/characters/arc/arc_normal.png',
  'apps/mobile/assets/characters/arc/arc_excited.png',
  'apps/mobile/assets/characters/arc/arc_support.png',
  'apps/mobile/assets/characters/arc/arc_serious.png',
  'apps/mobile/assets/characters/arc/arc_worried.png',
  'apps/mobile/assets/characters/arc/arc_lonely.png',
  'apps/mobile/assets/characters/arc/arc_celebrate.png',
];

const arcAssetMaxBytes = 300 * 1024;

const requiredFiles = {
  'apps/mobile/lib/features/quest/quest_repository.dart': [
    '.limit(limit)',
    '.select(',
  ],
  'apps/mobile/lib/features/mission/mission_repository.dart': [
    '.limit(limit)',
    '.select(',
  ],
  'apps/mobile/lib/features/trail/trail_repository.dart': [
    '.limit(limit)',
    '.select(',
  ],
  'apps/mobile/lib/features/arc_memory/arc_memory_repository.dart': [
    '.limit(limit)',
    '.select(',
    'importance',
  ],
  'apps/mobile/lib/features/trail/trail_screen.dart': [
    'trailImageMaxWidth',
    'trailImageMaxHeight',
    'trailImageQuality',
  ],
  'apps/mobile/lib/features/arc/arc_screen.dart': ['isThinking'],
  'README.md': [
    'flutter run --profile',
    'Home first render target',
    'dart run tools/qst/verify_performance_readiness.dart',
  ],
};

void main() {
  final failures = <String>[];

  for (final assetPath in approvedArcAssets) {
    final file = File(assetPath);
    if (!file.existsSync()) {
      failures.add('Missing approved Arc asset: $assetPath');
      continue;
    }
    final size = file.lengthSync();
    if (size > arcAssetMaxBytes) {
      failures.add('$assetPath is $size bytes, over $arcAssetMaxBytes bytes.');
    }
  }

  for (final entry in requiredFiles.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) {
      failures.add('Missing required file: ${entry.key}');
      continue;
    }
    final content = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!content.contains(snippet)) {
        failures.add('Missing "$snippet" in ${entry.key}');
      }
    }
  }

  final pubspec = File('apps/mobile/pubspec.yaml');
  if (!pubspec.existsSync() ||
      !pubspec.readAsStringSync().contains('assets/characters/arc/')) {
    failures.add('Arc asset directory is not registered in pubspec.yaml.');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Performance readiness verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Performance readiness verification passed.');
  stdout.writeln('Checked ${approvedArcAssets.length} approved Arc assets.');
  stdout.writeln(
    'Checked ${requiredFiles.length} performance-sensitive files.',
  );
}
