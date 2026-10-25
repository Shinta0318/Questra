import 'package:flutter_test/flutter_test.dart';

import '../../../tools/qst/verify_primary_screen_state_evidence.dart'
    show validatePrimaryScreenEvidence;

void main() {
  test('unverified or incomplete primary-screen evidence blocks release', () {
    final pending = validatePrimaryScreenEvidence(
      const {
        'version': 1,
        'status': 'pending',
        'candidateSha': null,
        'workingTreeCleanAtCapture': false,
        'screenshots': [],
        'physical': {},
      },
      candidateSha: 'a' * 40,
      worktreeClean: false,
      fileExists: (_) => false,
    );
    expect(pending, contains(contains('clean current SHA')));
    expect(pending, contains(contains('home at 360px')));
    expect(
      pending,
      contains(contains('route recovery state: recovery_incomplete')),
    );
    expect(pending, contains(contains('Arc AI fallback')));
    expect(pending, contains(contains('Physical accessibility')));
  });
}
