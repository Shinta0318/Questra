import 'dart:convert';

import 'external_beta_go_no_go.dart';

void main() {
  const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const projectRef = 'abcdefghijklmnopqrst';
  final device =
      '''status: verified
results:
${['android_phone', 'small_phone', 'large_phone', 'tablet', 'web_sanity'].map((name) => '  - class: $name\n    status: passed\n    candidate_source_commit: "$sha"\n').join()}ios:
  availability: unavailable
guardrails:
  mock_server_is_device_evidence: false
''';
  bool deviceGate({
    String? evidence,
    String? webSession,
    String? androidSession,
    bool candidatePassed = true,
    bool matrixPassed = true,
    bool webPassed = true,
    bool androidPassed = true,
  }) => betaDeviceEvidenceGatePassed(
    candidatePassed: candidatePassed,
    primaryStateEvidencePassed: true,
    device: evidence ?? device,
    webSession: webSession ?? 'candidate_sha: "$sha"\n',
    androidSession: androidSession ?? 'candidate_sha: "$sha"\n',
    sourceCommit: sha,
    verifyMatrix: () => matrixPassed,
    verifyWeb: () => webPassed,
    verifyAndroid: () => androidPassed,
  );
  if (!deviceGate() ||
      deviceGate(candidatePassed: false) ||
      deviceGate(matrixPassed: false) ||
      deviceGate(webPassed: false) ||
      deviceGate(androidPassed: false) ||
      deviceGate(webSession: 'candidate_sha: "${'b' * 40}"\n') ||
      deviceGate(androidSession: 'candidate_sha: "${'b' * 40}"\n') ||
      deviceGate(evidence: device.replaceFirst(sha, 'b' * 40))) {
    throw StateError('Device evidence must be candidate-bound and verified.');
  }
  final rlsEvidence =
      '''status: verified
source_commit_at_execution: "$sha"
project_ref: "$projectRef"
working_tree_clean_at_execution: true
''';
  final dualEvidence = rlsEvidence;
  var cloudChecks = 0;
  bool rlsGate({
    String? rls,
    String? dual,
    bool hostedPassed = true,
    bool cloudPassed = true,
    bool dualPassed = true,
  }) => betaOwnershipRlsGatePassed(
    hostedPassed: hostedPassed,
    rls: rls ?? rlsEvidence,
    dual: dual ?? dualEvidence,
    sourceCommit: sha,
    projectRef: projectRef,
    verifyCloudRls: () {
      cloudChecks++;
      return cloudPassed;
    },
    verifyDualAccount: () => dualPassed,
  );
  if (!rlsGate() || cloudChecks != 1) {
    throw StateError('Verified cloud RLS and dual-account evidence must pass.');
  }
  final invalidRls = <String, bool>{
    'hosted run failed': rlsGate(hostedPassed: false),
    'rls pending': rlsGate(
      rls: rlsEvidence.replaceFirst('status: verified', 'status: pending'),
    ),
    'dual account stale': rlsGate(
      dual: dualEvidence.replaceFirst(sha, 'b' * 40),
    ),
    'cloud replay failed': rlsGate(cloudPassed: false),
    'dual-account replay failed': rlsGate(dualPassed: false),
  };
  if (invalidRls.values.any((passed) => passed)) {
    throw StateError('Incomplete RLS evidence passed: $invalidRls');
  }
  final feedback =
      '''status: verified
candidate_source_commit: "$sha"
destination:
  status: verified
  channel_label: Beta feedback
daily_triage:
  status: active
  owner_name: Release Manager
stop_communication:
  status: verified
  channel_label: Beta stop channel
''';
  final issues =
      '''status: ready_to_use
candidate_source_commit: "$sha"
counts:
  status: verified
  generated_at_utc: "2026-10-24T00:00:00Z"
  open_s0: 0
  open_s1: 0
''';
  if (!betaOperationsGatePassed(feedback, issues, sha)) {
    throw StateError('Verified, staffed operations evidence must pass.');
  }
  final invalidOperations = <String, (String, String, String)>{
    'wrong status': (
      feedback.replaceFirst('status: verified', 'status: active'),
      issues,
      sha,
    ),
    'stale source': (feedback, issues, 'older-source'),
    'open S0': (feedback, issues.replaceFirst('open_s0: 0', 'open_s0: 1'), sha),
    'missing owner': (
      feedback.replaceFirst('owner_name: Release Manager', 'owner_name: null'),
      issues,
      sha,
    ),
  };
  for (final entry in invalidOperations.entries) {
    final (badFeedback, badIssues, badSha) = entry.value;
    if (betaOperationsGatePassed(badFeedback, badIssues, badSha)) {
      throw StateError('Operations evidence passed: ${entry.key}');
    }
  }
  final report = <String, Object>{
    'passed': true,
    'candidate_source_commit': sha,
    'cases': 200,
    'safety_cases': 10,
    'human_review': {'passed': true},
    'metrics': {
      'provider_backed_rate': 100,
      'schema_success_rate': 99,
      'usage_coverage_rate': 95,
      'safety_expected_action_rate': 100,
      'safety_non_fallback_rate': 100,
      'critical_safety_violation': 0,
    },
  };
  var verified = 0;
  bool check(Map<String, Object> value, {bool candidatePassed = true}) =>
      providerEvaluationGatePassed(
        reportJson: jsonEncode(value),
        candidateSha: sha,
        candidatePassed: candidatePassed,
        verifyRun: () {
          verified++;
          return true;
        },
      );

  if (!check(report) || verified != 1) {
    throw StateError('A bound report and verified run must pass.');
  }
  if (check(report, candidatePassed: false) || verified != 1) {
    throw StateError('An unapproved candidate must not pass.');
  }
  if (check({...report, 'candidate_source_commit': 'old'}) || verified != 1) {
    throw StateError('A stale report must not pass.');
  }
  if (check({...report, 'passed': false}) || verified != 1) {
    throw StateError('A failed report must not pass.');
  }
  if (check({
        ...report,
        'human_review': {'passed': false},
      }) ||
      verified != 1) {
    throw StateError('Failed human review must not pass.');
  }
  if (check({
        ...report,
        'metrics': {'provider_backed_rate': 100},
      }) ||
      verified != 1) {
    throw StateError('Incomplete quality metrics must not pass.');
  }
  if (providerEvaluationGatePassed(
    reportJson: '{invalid',
    candidateSha: sha,
    candidatePassed: true,
    verifyRun: () => true,
  )) {
    throw StateError('Malformed report must not pass.');
  }
  if (providerEvaluationGatePassed(
    reportJson: jsonEncode(report),
    candidateSha: sha,
    candidatePassed: true,
    verifyRun: () => false,
  )) {
    throw StateError('An unverified provider run must not pass.');
  }
  print('External Beta provider gate fixtures: PASS.');
}
