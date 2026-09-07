import 'dart:io';

const externalBetaDecisionPath = 'docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml';

class ExternalBetaGate {
  const ExternalBetaGate({
    required this.id,
    required this.title,
    required this.passed,
    required this.evidence,
    required this.blocker,
  });

  final String id;
  final String title;
  final bool passed;
  final List<String> evidence;
  final String blocker;

  String get status => passed ? 'passed' : 'blocked';
}

class ExternalBetaDecision {
  const ExternalBetaDecision({
    required this.sourceCommit,
    required this.latestMigration,
    required this.worktreeCleanAtEvaluation,
    required this.gates,
  });

  final String sourceCommit;
  final String latestMigration;
  final bool worktreeCleanAtEvaluation;
  final List<ExternalBetaGate> gates;

  bool get distributionReady => gates.every((gate) => gate.passed);
  String get decision => distributionReady ? 'go' : 'no_go';
}

ExternalBetaDecision evaluateExternalBetaReadiness() {
  final sourceCommit = _command(['git', 'rev-parse', 'HEAD']).trim();
  final worktreeClean = _command([
    'git',
    'status',
    '--porcelain',
  ]).trim().isEmpty;
  final latestMigration = _latestMigration();

  final candidate = _read('docs/qst/BETA_CANDIDATE.yaml');
  final hosted = _read('docs/qst/HOSTED_EVIDENCE_RUN.yaml');
  final rls = _read('docs/qst/BETA_RLS_EVIDENCE.yaml');
  final dual = _read('docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml');
  final device = _read('docs/qst/BETA_DEVICE_VALIDATION.yaml');
  final physicalAccessibility = _read(
    'docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml',
  );
  final legal = _read('docs/qst/BETA_LEGAL_SIGNOFF.yaml');
  final assets = _read('docs/qst/ARC_ASSET_PROVENANCE.yaml');
  final assetPackage = _read('docs/qst/CANDIDATE_ASSET_PACKAGE.yaml');
  final licenses = _read('docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml');
  final runtime = _read('docs/qst/RUNTIME_SLO_DRILL.yaml');
  final observability = _read('docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml');
  final feedback = _read('docs/qst/BETA_FEEDBACK_OPERATIONS.yaml');
  final issues = _read('docs/qst/BETA_ISSUE_REGISTER.yaml');
  final aiRegression = _readOptional('reports/qst/QST-256-REGRESSION.json');

  final candidatePassed =
      _top(candidate, 'candidate_status') == 'approved' &&
      _bool(candidate, 'distribution_ready') &&
      _top(candidate, 'source_commit') == sourceCommit &&
      _bool(candidate, 'worktree_clean_before_manifest') &&
      worktreeClean;
  final hostedPassed =
      _top(hosted, 'status') == 'verified' &&
      _top(hosted, 'candidate_source_commit') == sourceCommit &&
      _bool(hosted, 'working_tree_clean_at_start') &&
      _top(hosted, 'latest_migration') == latestMigration &&
      _containsAll(hosted, const [
        'migrations_and_functions: passed',
        'data_export_owner_scope: passed',
        'correction_owner_scope: passed',
        'consent_withdrawal: passed',
        'ephemeral_accounts_removed: passed',
      ]);
  final rlsPassed =
      hostedPassed &&
      _containsAll(hosted, const [
        'rls_behavior: passed',
        'dual_account_journey: passed',
      ]) &&
      _top(rls, 'source_commit_at_execution') == sourceCommit &&
      _bool(rls, 'working_tree_clean_at_execution') &&
      _top(dual, 'source_commit_at_execution') == sourceCommit &&
      _bool(dual, 'working_tree_clean_at_execution');
  final devicePassed =
      _top(device, 'status') == 'verified' &&
      _containsAll(device, const ['web_sanity: passed']) &&
      device.contains(sourceCommit) &&
      _top(physicalAccessibility, 'status') == 'verified' &&
      _top(physicalAccessibility, 'candidate_sha') == sourceCommit &&
      _bool(physicalAccessibility, 'working_tree_clean_at_execution');
  final accessibilityPassed =
      devicePassed &&
      _containsAll(physicalAccessibility, const [
        'talkback: passed',
        'japanese_ime: passed',
        'large_text_200: passed',
        'compact_layout: passed',
        'reduced_motion_and_haptics: passed',
      ]);
  final legalPassed =
      _top(legal, 'status') == 'approved' &&
      _nested(legal, 'operator', 'legal_name') != null &&
      _top(legal, 'privacy_contact') != null &&
      _top(legal, 'support_contact') != null &&
      _nested(legal, 'signoffs', 'legal_reviewer') == 'approved' &&
      _nested(legal, 'signoffs', 'product_owner') == 'approved';
  final rightsPassed =
      _nested(legal, 'data_requests', 'request_procedure_verified') == 'true' &&
      _nested(legal, 'data_requests', 'account_deletion_available') == 'true' &&
      _nested(legal, 'data_requests', 'data_export_available') == 'true' &&
      _nested(legal, 'data_requests', 'correction_available') == 'true' &&
      _nested(legal, 'data_requests', 'consent_withdrawal_available') ==
          'true' &&
      _nested(legal, 'data_requests', 'hosted_owner_isolation_verified') ==
          'true' &&
      _nested(legal, 'data_requests', 'deletion_worker_verified') == 'true' &&
      hostedPassed;
  final assetsPassed =
      _top(assets, 'status') == 'approved' &&
      _top(assets, 'product_owner_approval') == 'approved' &&
      _top(assets, 'legal_reviewer_approval') == 'approved' &&
      _bool(assets, 'chain_of_title_complete') &&
      _top(assetPackage, 'status') == 'approved' &&
      _bool(assetPackage, 'release_ready');
  final licensesPassed =
      _top(licenses, 'status') == 'approved' &&
      _top(licenses, 'missing_license_file_count') == '0' &&
      _top(licenses, 'unpinned_npm_import_count') == '0' &&
      _top(licenses, 'product_owner_approval') == 'approved' &&
      _top(licenses, 'legal_reviewer_approval') == 'approved';
  final operationsPassed =
      _top(feedback, 'status') == 'active' &&
      _nested(feedback, 'destination', 'status') == 'verified' &&
      _nested(feedback, 'daily_triage', 'status') == 'active' &&
      _nested(issues, 'counts', 'open_s0') == '0' &&
      _nested(issues, 'counts', 'open_s1') == '0' &&
      _nested(issues, 'counts', 'status') == 'verified';
  final runtimePassed =
      _top(runtime, 'status') == 'hosted_alert_and_rollback_verified' &&
      _top(runtime, 'candidate_source_commit') == sourceCommit &&
      _bool(runtime, 'working_tree_clean_at_execution') &&
      _bool(runtime, 'hosted_sink_connected') &&
      _bool(runtime, 'alert_delivery_receipt_verified') &&
      _bool(runtime, 'rollback_execution_verified') &&
      _top(observability, 'status') ==
          'hosted_sink_alert_and_retention_verified' &&
      _top(observability, 'candidate_source_commit') == sourceCommit &&
      _bool(observability, 'working_tree_clean_at_execution') &&
      _bool(observability, 'hosted_sink_enabled');
  final aiPassed =
      aiRegression.isNotEmpty &&
      RegExp(r'"passed"\s*:\s*true').hasMatch(aiRegression) &&
      _jsonNumber(aiRegression, 'provider_backed_rate') >= 100 &&
      _jsonNumber(aiRegression, 'schema_success_rate') >= 99 &&
      _jsonNumber(aiRegression, 'usage_coverage_rate') >= 95 &&
      _jsonNumber(aiRegression, 'safety_expected_action_rate') >= 100 &&
      _jsonNumber(aiRegression, 'critical_safety_violation') == 0;

  return ExternalBetaDecision(
    sourceCommit: sourceCommit,
    latestMigration: latestMigration,
    worktreeCleanAtEvaluation: worktreeClean,
    gates: [
      ExternalBetaGate(
        id: 'candidate_identity',
        title: 'Candidate identity and immutable artifacts',
        passed: candidatePassed,
        evidence: const ['docs/qst/BETA_CANDIDATE.yaml'],
        blocker:
            'Approve a clean SHA-bound candidate with checksummed artifacts.',
      ),
      ExternalBetaGate(
        id: 'hosted_supabase',
        title: 'Hosted migrations and Edge Functions',
        passed: hostedPassed,
        evidence: const [
          'docs/qst/HOSTED_EVIDENCE_RUN.yaml',
          'docs/qst/BETA_SUPABASE_PROJECT.yaml',
        ],
        blocker:
            'Deploy the latest migration and functions from this clean candidate SHA.',
      ),
      ExternalBetaGate(
        id: 'ownership_rls',
        title: 'Two-account persistence and RLS',
        passed: rlsPassed,
        evidence: const [
          'docs/qst/BETA_RLS_EVIDENCE.yaml',
          'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml',
        ],
        blocker:
            'Repeat the full two-account owner-isolation suite on this candidate SHA.',
      ),
      ExternalBetaGate(
        id: 'real_devices',
        title: 'Physical Android and Web candidate journey',
        passed: devicePassed,
        evidence: const ['docs/qst/BETA_DEVICE_VALIDATION.yaml'],
        blocker:
            'Capture candidate-bound physical Android and supported Web evidence.',
      ),
      ExternalBetaGate(
        id: 'accessibility_ime',
        title: 'TalkBack, 200% text, and Japanese IME',
        passed: accessibilityPassed,
        evidence: const [
          'docs/qst/BETA_DEVICE_VALIDATION.yaml',
          'docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml',
          'docs/product/accessibility_release_gate.md',
        ],
        blocker:
            'Complete physical TalkBack, 200% text, and Japanese IME checks.',
      ),
      ExternalBetaGate(
        id: 'legal_privacy',
        title: 'Legal, privacy, operator, and contacts',
        passed: legalPassed,
        evidence: const ['docs/qst/BETA_LEGAL_SIGNOFF.yaml'],
        blocker:
            'Record operator/contact facts and dated Product and Legal approval.',
      ),
      ExternalBetaGate(
        id: 'data_rights',
        title: 'Data rights fulfillment and retention',
        passed: rightsPassed,
        evidence: const [
          'docs/qst/BETA_LEGAL_SIGNOFF.yaml',
          'docs/qst/HOSTED_EVIDENCE_RUN.yaml',
        ],
        blocker:
            'Verify hosted export, correction, withdrawal, deletion, and retention operations.',
      ),
      ExternalBetaGate(
        id: 'arc_asset_rights',
        title: 'Arc asset chain of title',
        passed: assetsPassed,
        evidence: const [
          'docs/qst/ARC_ASSET_PROVENANCE.yaml',
          'docs/qst/CANDIDATE_ASSET_PACKAGE.yaml',
        ],
        blocker:
            'Complete chain-of-title evidence and Product/Legal approval for bundled Arc assets.',
      ),
      ExternalBetaGate(
        id: 'dependency_licenses',
        title: 'Dependency license notices',
        passed: licensesPassed,
        evidence: const [
          'docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml',
          'docs/legal/THIRD_PARTY_NOTICES.md',
        ],
        blocker:
            'Pin server imports exactly and complete Product/Legal license review.',
      ),
      ExternalBetaGate(
        id: 'operations_incidents',
        title: 'Feedback and incident operations',
        passed: operationsPassed,
        evidence: const [
          'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml',
          'docs/qst/BETA_ISSUE_REGISTER.yaml',
        ],
        blocker:
            'Activate the tester channel, named triage owner, and verified S0/S1 counts.',
      ),
      ExternalBetaGate(
        id: 'runtime_slo',
        title: 'Hosted runtime SLO alert and rollback drill',
        passed: runtimePassed,
        evidence: const [
          'docs/qst/RUNTIME_SLO_DRILL.yaml',
          'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml',
        ],
        blocker:
            'Connect the privacy-safe sink and verify alert receipt and rollback execution.',
      ),
      ExternalBetaGate(
        id: 'ai_quality_cost',
        title: 'Provider-backed AI quality and cost gate',
        passed: aiPassed,
        evidence: const [
          'reports/qst/QST-256-REGRESSION.json',
          'reports/qst/QST-256.md',
        ],
        blocker:
            'Run the 200-case provider-backed suite and pass quality, safety, latency, and cost review.',
      ),
    ],
  );
}

String renderExternalBetaDecision(
  ExternalBetaDecision decision, {
  required DateTime evaluatedAt,
}) {
  final buffer = StringBuffer()
    ..writeln('version: 1')
    ..writeln('qst: QST-367')
    ..writeln('decision: ${decision.decision}')
    ..writeln('distribution_ready: ${decision.distributionReady}')
    ..writeln('evaluated_at_utc: "${evaluatedAt.toUtc().toIso8601String()}"')
    ..writeln('candidate_source_commit: "${decision.sourceCommit}"')
    ..writeln('latest_local_migration: "${decision.latestMigration}"')
    ..writeln(
      'worktree_clean_at_evaluation: ${decision.worktreeCleanAtEvaluation}',
    )
    ..writeln('summary:')
    ..writeln('  passed: ${decision.gates.where((gate) => gate.passed).length}')
    ..writeln(
      '  blocked: ${decision.gates.where((gate) => !gate.passed).length}',
    )
    ..writeln('gates:');
  for (final gate in decision.gates) {
    buffer
      ..writeln('  - id: ${gate.id}')
      ..writeln('    title: "${_yaml(gate.title)}"')
      ..writeln('    status: ${gate.status}')
      ..writeln('    evidence:');
    for (final path in gate.evidence) {
      buffer.writeln('      - "$path"');
    }
    if (!gate.passed) {
      buffer.writeln('    blocker: "${_yaml(gate.blocker)}"');
    }
  }
  buffer
    ..writeln('guardrails:')
    ..writeln('  static_test_is_external_evidence: false')
    ..writeln('  local_fallback_is_provider_evidence: false')
    ..writeln('  stale_sha_evidence_allowed: false')
    ..writeln('  human_approval_inferred_from_code: false')
    ..writeln('  any_blocked_gate_allows_distribution: false')
    ..writeln('  destructive_database_rollback_allowed: false');
  return buffer.toString();
}

String _latestMigration() {
  final migrations =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();
  if (migrations.isEmpty) throw StateError('No Supabase migration found.');
  return migrations.last;
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) {
    throw StateError('${command.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync())
    throw StateError('Required evidence is missing: $path');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

String _readOptional(String path) =>
    File(path).existsSync() ? File(path).readAsStringSync() : '';

String? _top(String content, String key) {
  final match = RegExp(
    '^${RegExp.escape(key)}:\\s*"?([^"\\n]+?)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content);
  final value = match?.group(1)?.trim();
  return value == null || value == 'null' ? null : value;
}

String? _nested(String content, String section, String key) {
  final sectionMatch = RegExp(
    '^${RegExp.escape(section)}:\\s*\$([\\s\\S]*?)(?=^[^ \\n][^:\\n]*:|\\z)',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) return null;
  final match = RegExp(
    '^  ${RegExp.escape(key)}:\\s*"?([^"\\n]+?)"?\\s*\$',
    multiLine: true,
  ).firstMatch(sectionMatch.group(1)!);
  final value = match?.group(1)?.trim();
  return value == null || value == 'null' ? null : value;
}

bool _bool(String content, String key) => _top(content, key) == 'true';

bool _containsAll(String content, List<String> snippets) =>
    snippets.every(content.contains);

double _jsonNumber(String content, String key) {
  final match = RegExp(
    '"${RegExp.escape(key)}"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)',
  ).firstMatch(content);
  return double.tryParse(match?.group(1) ?? '') ?? -1;
}

String _yaml(String value) => value.replaceAll('"', '\\"');
