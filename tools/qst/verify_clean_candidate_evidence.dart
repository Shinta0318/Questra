import 'dart:convert';
import 'dart:io';

import 'candidate_git_state.dart';

void main(List<String> arguments) {
  final expected = arguments
      .where((argument) => argument.startsWith('--expected-sha='))
      .map((argument) => argument.substring('--expected-sha='.length))
      .firstOrNull;
  if (expected == null || !RegExp(r'^[a-f0-9]{40}$').hasMatch(expected)) {
    _fail('A valid --expected-sha is required.');
  }
  final head = Process.runSync('git', ['rev-parse', 'HEAD']);
  if (head.exitCode != 0 || head.stdout.toString().trim() != expected) {
    _fail('Expected candidate SHA does not match current HEAD.');
  }
  const allowedEvidenceOutputs = {
    'docs/qst/BETA_CANDIDATE.yaml',
    'docs/qst/HOSTED_EVIDENCE_RUN.yaml',
    'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml',
    'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml',
    'docs/qst/RUNTIME_SLO_DRILL.yaml',
    'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml',
    'docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml',
    'docs/qst/WEB_CANDIDATE_SESSION.yaml',
    'docs/qst/ANDROID_CANDIDATE_SESSION.yaml',
    'docs/qst/LEGAL_SIGNOFF_INTAKE.yaml',
    'docs/qst/BETA_LEGAL_SIGNOFF.yaml',
    'docs/qst/LEGAL_VERSION_RECONCILIATION.yaml',
    'docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml',
    'docs/legal/THIRD_PARTY_NOTICES.md',
    'docs/qst/CANDIDATE_ASSET_PACKAGE.yaml',
    'docs/qst/ARC_ASSET_RELEASE_DECISION.yaml',
    'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml',
    'docs/qst/BETA_ISSUE_REGISTER.yaml',
    'docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml',
    'reports/qst/QST-256-REGRESSION.json',
    'reports/qst/QST-400-HUMAN-REVIEW.json',
    'docs/qst/PROVIDER_EVAL_RUN.yaml',
    'docs/qst/INCIDENT_LIVE_DRILL.yaml',
    'tools/qst/quest_planning_eval_results.json',
  };
  final changed = candidateChangedPaths();
  final nonEvidenceChanges = changed.difference(allowedEvidenceOutputs);
  if (nonEvidenceChanges.isNotEmpty) {
    _fail(
      'Candidate contains non-evidence changes: ${nonEvidenceChanges.join(', ')}',
    );
  }

  final yamlEvidence = <String, String>{
    'docs/qst/BETA_CANDIDATE.yaml': 'source_commit',
    'docs/qst/HOSTED_EVIDENCE_RUN.yaml': 'candidate_source_commit',
    'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml': 'candidate_source_commit',
    'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml': 'candidate_source_commit',
    'docs/qst/RUNTIME_SLO_DRILL.yaml': 'candidate_source_commit',
    'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml': 'candidate_source_commit',
    'docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml': 'candidate_sha',
    'docs/qst/WEB_CANDIDATE_SESSION.yaml': 'candidate_sha',
    'docs/qst/ANDROID_CANDIDATE_SESSION.yaml': 'candidate_sha',
    'docs/qst/LEGAL_SIGNOFF_INTAKE.yaml': 'candidate_source_commit',
    'docs/qst/BETA_LEGAL_SIGNOFF.yaml': 'candidate_source_commit',
    'docs/qst/LEGAL_VERSION_RECONCILIATION.yaml': 'candidate_source_commit',
    'docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml': 'candidate_source_commit',
    'docs/qst/CANDIDATE_ASSET_PACKAGE.yaml': 'candidate_source_commit',
    'docs/qst/ARC_ASSET_RELEASE_DECISION.yaml': 'candidate_source_commit',
    'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml': 'candidate_source_commit',
    'docs/qst/BETA_ISSUE_REGISTER.yaml': 'candidate_source_commit',
    'docs/qst/PROVIDER_EVAL_RUN.yaml': 'candidate_source_commit',
    'docs/qst/INCIDENT_LIVE_DRILL.yaml': 'candidate_source_commit',
  };
  for (final entry in yamlEvidence.entries) {
    final content = _read(entry.key);
    final value = RegExp(
      '^${RegExp.escape(entry.value)}:\\s*"?([a-f0-9]{40})"?\\s*\$',
      multiLine: true,
    ).firstMatch(content)?.group(1);
    if (value != expected) {
      _fail('${entry.key} is not bound to expected candidate SHA.');
    }
  }
  final requiredEvidenceStates = <String, List<String>>{
    'docs/qst/HOSTED_EVIDENCE_RUN.yaml': [
      'status: verified',
      'working_tree_clean_at_start: true',
    ],
    'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml': [
      'status: verified',
      'working_tree_clean_at_execution: true',
    ],
    'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml': [
      'status: hosted_fulfillment_verified',
      'working_tree_clean_at_execution: true',
    ],
    'docs/qst/RUNTIME_SLO_DRILL.yaml': [
      'status: hosted_alert_and_rollback_verified',
      'working_tree_clean_at_execution: true',
    ],
    'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml': [
      'status: hosted_sink_alert_and_retention_verified',
      'working_tree_clean_at_execution: true',
    ],
    'docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml': [
      'status: verified',
      'working_tree_clean_at_execution: true',
    ],
    'docs/qst/WEB_CANDIDATE_SESSION.yaml': [
      'status: verified',
      'working_tree_clean_at_execution: true',
    ],
    'docs/qst/ANDROID_CANDIDATE_SESSION.yaml': [
      'status: verified',
      'working_tree_clean_at_execution: true',
    ],
    'docs/qst/LEGAL_SIGNOFF_INTAKE.yaml': [
      'status: approved',
      'working_tree_clean_at_intake: true',
    ],
    'docs/qst/BETA_LEGAL_SIGNOFF.yaml': [
      'status: approved',
      'working_tree_clean_at_signoff: true',
    ],
    'docs/qst/LEGAL_VERSION_RECONCILIATION.yaml': [
      'status: versions_aligned_approved',
    ],
    'docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml': ['status: approved'],
    'docs/qst/CANDIDATE_ASSET_PACKAGE.yaml': [
      'status: approved',
      'working_tree_clean_at_generation: true',
    ],
    'docs/qst/ARC_ASSET_RELEASE_DECISION.yaml': [
      'status: approved',
      'working_tree_clean_before_apply: true',
      'approved_runtime_asset_count: 7',
    ],
    'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml': ['status: verified'],
    'docs/qst/PROVIDER_EVAL_RUN.yaml': [
      'status: verified',
      'automated_gate_passed: true',
      'human_gate_passed: true',
    ],
    'docs/qst/INCIDENT_LIVE_DRILL.yaml': [
      'status: verified',
      'working_tree_clean_at_execution: true',
      '  restored_verified: true',
      '  rollback_launch_verified: true',
    ],
    'docs/qst/BETA_ISSUE_REGISTER.yaml': ['  status: verified'],
  };
  for (final entry in requiredEvidenceStates.entries) {
    final content = _read(entry.key);
    for (final required in entry.value) {
      if (!content.contains(required)) {
        _fail('${entry.key} is missing strict state: $required');
      }
    }
  }

  final aiReport = jsonDecode(_read('reports/qst/QST-256-REGRESSION.json'));
  if (aiReport is! Map ||
      aiReport['candidate_source_commit'] != expected ||
      aiReport['passed'] != true) {
    _fail('Provider-backed AI evidence is missing, stale, or failed.');
  }
  final candidate = _read('docs/qst/BETA_CANDIDATE.yaml');
  for (final required in [
    'candidate_status: "approved"',
    'distribution_ready: true',
    'worktree_clean_before_manifest: true',
    'external_evidence:\n  complete: true\n  matches_candidate_sha: true',
  ]) {
    if (!candidate.contains(required))
      _fail('Candidate gate missing: $required');
  }
  if (!RegExp(r'sha256: "[a-f0-9]{64}"').hasMatch(candidate)) {
    _fail('Candidate artifact checksum is missing.');
  }
  stdout.writeln('Clean candidate evidence is complete and SHA-consistent.');
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing candidate evidence: $path');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
