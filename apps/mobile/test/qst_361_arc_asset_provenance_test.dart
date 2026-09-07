import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runtime Arc assets are tracked and mock references are not bundled',
    () {
      final manifest = File(
        '../../docs/qst/ARC_ASSET_PROVENANCE.yaml',
      ).readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final assets = Directory(
        'assets/characters/arc',
      ).listSync().whereType<File>();
      for (final asset in assets) {
        final path = 'apps/mobile/${asset.path.replaceAll('\\', '/')}';
        expect(manifest, contains('path: "$path"'));
      }
      expect(pubspec, contains('- assets/characters/arc/'));
      expect(pubspec, isNot(contains('- assets/mockups/')));
      expect(manifest, contains('chain_of_title_complete: false'));
      expect(manifest, isNot(contains('release_allowed: true')));
    },
  );
}
