import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repositoryRoot = Directory.current.parent.parent;

  test(
    'release gate regenerates Android plugin configuration before build',
    () {
      final workflow = File(
        '${repositoryRoot.path}/.github/workflows/release-gate.yml',
      ).readAsStringSync();

      final configureIndex = workflow.indexOf(
        'run: flutter build apk --config-only',
      );
      final releaseIndex = workflow.indexOf(
        'run: flutter build apk --release --no-pub',
      );

      expect(configureIndex, greaterThanOrEqualTo(0));
      expect(releaseIndex, greaterThan(configureIndex));
      expect(
        workflow,
        isNot(contains('prepare_android_release_registrant.dart')),
      );
    },
  );

  test('draft candidate accepts complete artifact checksum evidence', () {
    final verifier = File(
      '${repositoryRoot.path}/tools/qst/verify_beta_candidate_manifest.dart',
    ).readAsStringSync();

    expect(verifier, contains('_checkArtifacts(failures)'));
    expect(verifier, contains('status: found'));
    expect(verifier, contains(r'[a-f0-9]{64}'));
    expect(verifier, isNot(contains("'status: not_built',")));
  });
}
