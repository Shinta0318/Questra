import 'dart:io';

import 'verify_migration_drift.dart' as drift;

void main() {
  const rlsPath = 'docs/qst/BETA_RLS_EVIDENCE.yaml';
  const rlsPending = '''
status: local_migration_pending_deployment
working_tree_clean_at_execution: false
migrations:
  latest_local: "old_migration.sql"
''';
  _expect(
    drift.isHistoricalPendingEvidence(rlsPath, rlsPending),
    'pending RLS',
  );
  _expect(
    !drift.isHistoricalPendingEvidence(
      rlsPath,
      rlsPending.replaceFirst(
        'working_tree_clean_at_execution: false',
        'working_tree_clean_at_execution: true',
      ),
    ),
    'claimed executed RLS',
  );

  const candidatePath = 'docs/qst/BETA_CANDIDATE.yaml';
  const draft = '''
candidate_status: "draft"
distribution_ready: false
inventory:
  latest_local_migration: "old_migration.sql"
''';
  _expect(
    drift.isHistoricalPendingEvidence(candidatePath, draft),
    'draft candidate',
  );
  _expect(
    !drift.isHistoricalPendingEvidence(
      candidatePath,
      draft.replaceFirst(
        'distribution_ready: false',
        'distribution_ready: true',
      ),
    ),
    'distribution-ready candidate',
  );

  const hostedPath = 'docs/qst/HOSTED_EVIDENCE_RUN.yaml';
  const pendingRun = '''
status: pending_candidate_run
executed_at_utc: null
latest_migration: "old_migration.sql"
''';
  _expect(
    drift.isHistoricalPendingEvidence(hostedPath, pendingRun),
    'pending hosted run',
  );
  _expect(
    !drift.isHistoricalPendingEvidence(
      hostedPath,
      pendingRun.replaceFirst(
        'executed_at_utc: null',
        'executed_at_utc: "2026-11-03T00:00:00Z"',
      ),
    ),
    'claimed executed hosted run',
  );

  _expect(
    !drift.isHistoricalPendingEvidence(
      'docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml',
      'decision: no_go',
    ),
    'current NO-GO decision',
  );
  stdout.writeln('Historical pending migration evidence contract passed.');
}

void _expect(bool value, String label) {
  if (!value)
    throw StateError('Incorrect historical evidence handling: $label');
}
