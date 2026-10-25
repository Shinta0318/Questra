import 'package:flutter_test/flutter_test.dart';

import '../../../tools/qst/verify_hosted_route_evidence.dart'
    show validateHostedRouteEvidence;

void main() {
  test('Hosted route gate rejects pending and missing two-account proof', () {
    final errors = validateHostedRouteEvidence(
      const {
        'version': 1,
        'status': 'pending',
        'candidateSha': null,
        'migrationHead': null,
        'projectRef': null,
        'workingTreeCleanAtExecution': false,
        'checks': {},
        'sanitizedEvidencePaths': [],
      },
      candidateSha: 'a' * 40,
      migrationHead: 'migration.sql',
      projectRef: 'test-project',
      worktreeClean: false,
      fileExists: (_) => false,
    );
    expect(errors, contains(contains('clean current candidate')));
    expect(errors, contains(contains('snapshotV2Reload')));
    expect(errors, contains(contains('crossAccountDenied')));
    expect(errors, contains(contains('lostResponseRetry')));
    expect(errors, contains(contains('Sanitized Hosted evidence')));
  });
}
