import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final workflow = File(
    '../../docs/product/arc_asset_ownership_workflow.md',
  ).readAsStringSync();

  test(
    'Flutter package includes runtime Arc assets but excludes mock references',
    () {
      expect(pubspec, contains('- assets/characters/arc/'));
      expect(pubspec, isNot(contains('- assets/mockups/')));
    },
  );

  test('ownership workflow invalidates approval on hash change', () {
    expect(workflow, contains('Any byte change creates a new asset identity'));
    expect(workflow, contains('release_allowed` returns to `false'));
    expect(workflow, contains('--require-release'));
  });
}
