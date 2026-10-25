import 'dart:io';
import 'dart:convert';

import 'candidate_git_state.dart';
import 'candidate_artifacts.dart';

import 'verify_primary_screen_state_evidence.dart'
    show validatePrimaryScreenEvidence;
import 'verify_hosted_route_evidence.dart' show validateHostedRouteEvidence;

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
  final currentHead = _command(['git', 'rev-parse', 'HEAD']).trim();
  final worktreeClean = _command([
    'git',
    'status',
    '--porcelain',
  ]).trim().isEmpty;
  final latestMigration = _latestMigration();

  final candidate = _read('docs/qst/BETA_CANDIDATE.yaml');
  final declaredSource = _top(candidate, 'source_commit');
  final sourceIsValid =
      declaredSource != null &&
      candidateSourceHasOnlyEvidenceCommits(declaredSource);
  final sourceCommit = sourceIsValid ? declaredSource : currentHead;
  final hosted = _read('docs/qst/HOSTED_EVIDENCE_RUN.yaml');
  final project = _read('docs/qst/BETA_SUPABASE_PROJECT.yaml');
  final emailDelivery = _read('docs/qst/BETA_EMAIL_DELIVERY_EVIDENCE.yaml');
  final authRedirects = _read('docs/qst/BETA_AUTH_REDIRECT_EVIDENCE.json');
  final rls = _read('docs/qst/BETA_RLS_EVIDENCE.yaml');
  final dual = _read('docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml');
  final device = _read('docs/qst/BETA_DEVICE_VALIDATION.yaml');
  final webSession = _read('docs/qst/WEB_CANDIDATE_SESSION.yaml');
  final androidSession = _read('docs/qst/ANDROID_CANDIDATE_SESSION.yaml');
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
  var primaryStateEvidencePassed = false;
  try {
    final decoded = jsonDecode(
      _read('docs/qst/PRIMARY_SCREEN_STATE_EVIDENCE.json'),
    );
    if (decoded is Map) {
      primaryStateEvidencePassed = validatePrimaryScreenEvidence(
        Map<String, dynamic>.from(decoded),
        candidateSha: sourceCommit,
        worktreeClean: worktreeClean,
        fileExists: (path) =>
            File(path).existsSync() && File(path).lengthSync() > 0,
      ).isEmpty;
    }
  } catch (_) {
    primaryStateEvidencePassed = false;
  }
  var hostedRouteEvidencePassed = false;
  try {
    final decoded = jsonDecode(_read('docs/qst/HOSTED_ROUTE_EVIDENCE.json'));
    if (decoded is Map) {
      hostedRouteEvidencePassed = validateHostedRouteEvidence(
        Map<String, dynamic>.from(decoded),
        candidateSha: sourceCommit,
        migrationHead: latestMigration,
        projectRef: _nested(project, 'project', 'ref') ?? '',
        worktreeClean: worktreeClean,
        fileExists: (path) =>
            File(path).existsSync() && File(path).lengthSync() > 0,
      ).isEmpty;
    }
  } catch (_) {
    hostedRouteEvidencePassed = false;
  }

  final candidatePassed =
      sourceIsValid &&
      _top(candidate, 'candidate_status') == 'approved' &&
      _bool(candidate, 'distribution_ready') &&
      _top(candidate, 'source_commit') == sourceCommit &&
      _bool(candidate, 'worktree_clean_before_manifest') &&
      worktreeClean &&
      candidateArtifactsVerified(candidate, sourceCommit);
  final hostedPassed =
      hostedRouteEvidencePassed &&
      _top(hosted, 'status') == 'verified' &&
      _top(hosted, 'candidate_source_commit') == sourceCommit &&
      _bool(hosted, 'working_tree_clean_at_start') &&
      _top(hosted, 'latest_migration') == latestMigration &&
      _containsAll(hosted, const [
        'migrations_and_functions: passed',
        'ai_user_boundary: passed',
        'data_export_owner_scope: passed',
        'correction_owner_scope: passed',
        'consent_withdrawal: passed',
        'ephemeral_accounts_removed: passed',
      ]);
  final emailDeliveryPassed = validateBetaEmailDeliveryEvidence(
    emailDelivery,
    candidateSha: sourceCommit,
    projectRef: _nested(project, 'project', 'ref') ?? '',
    worktreeClean: worktreeClean,
    fileExists: (path) =>
        File(path).existsSync() && File(path).lengthSync() > 0,
  );
  var authRedirectsPassed = false;
  try {
    final decoded = jsonDecode(authRedirects);
    if (decoded is Map) {
      authRedirectsPassed = validateBetaAuthRedirectEvidence(
        Map<String, dynamic>.from(decoded),
        candidateSha: sourceCommit,
        projectRef: _nested(project, 'project', 'ref') ?? '',
        worktreeClean: worktreeClean,
        fileExists: (path) =>
            File(path).existsSync() && File(path).lengthSync() > 0,
      );
    }
  } catch (_) {
    authRedirectsPassed = false;
  }
  final rlsPassed = betaOwnershipRlsGatePassed(
    hostedPassed:
        hostedPassed &&
        _containsAll(hosted, const [
          'rls_behavior: passed',
          'dual_account_journey: passed',
        ]),
    rls: rls,
    dual: dual,
    sourceCommit: sourceCommit,
    projectRef: _nested(project, 'project', 'ref') ?? '',
    verifyCloudRls: () =>
        Process.runSync(Platform.resolvedExecutable, [
          'run',
          'tools/qst/verify_cloud_rls_evidence.dart',
          '--require-cloud',
        ]).exitCode ==
        0,
    verifyDualAccount: () =>
        Process.runSync(Platform.resolvedExecutable, [
          'run',
          'tools/qst/verify_dual_account_persistence.dart',
          '--require-cloud',
        ]).exitCode ==
        0,
  );
  final devicePassed = betaDeviceEvidenceGatePassed(
    candidatePassed: candidatePassed,
    primaryStateEvidencePassed: primaryStateEvidencePassed,
    device: device,
    webSession: webSession,
    androidSession: androidSession,
    sourceCommit: sourceCommit,
    verifyMatrix: () => _verifyDartGate(
      'tools/qst/verify_real_device_validation_readiness.dart',
      '--require-devices',
    ),
    verifyWeb: () => _verifyDartGate(
      'tools/qst/verify_web_candidate_evidence.dart',
      '--require-web',
    ),
    verifyAndroid: () => _verifyDartGate(
      'tools/qst/verify_android_candidate_evidence.dart',
      '--require-physical',
    ),
  );
  final accessibilityPassed =
      devicePassed &&
      _top(physicalAccessibility, 'status') == 'verified' &&
      _top(physicalAccessibility, 'candidate_sha') == sourceCommit &&
      _bool(physicalAccessibility, 'working_tree_clean_at_execution') &&
      _verifyDartGate(
        'tools/qst/verify_physical_accessibility_evidence.dart',
        '--require-physical',
      ) &&
      _containsAll(physicalAccessibility, const [
        'talkback: passed',
        'japanese_ime: passed',
        'large_text_200: passed',
        'compact_layout: passed',
        'reduced_motion_and_haptics: passed',
      ]);
  final legalPassed =
      _top(legal, 'status') == 'approved' &&
      _top(legal, 'candidate_source_commit') == sourceCommit &&
      _bool(legal, 'working_tree_clean_at_signoff') &&
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
      _top(assets, 'candidate_source_commit') == sourceCommit &&
      _top(assets, 'product_owner_approval') == 'approved' &&
      _top(assets, 'legal_reviewer_approval') == 'approved' &&
      _bool(assets, 'chain_of_title_complete') &&
      _top(assetPackage, 'status') == 'approved' &&
      _top(assetPackage, 'candidate_source_commit') == sourceCommit &&
      _bool(assetPackage, 'working_tree_clean_at_generation') &&
      _bool(assetPackage, 'release_ready');
  final licensesPassed =
      _top(licenses, 'status') == 'approved' &&
      _top(licenses, 'candidate_source_commit') == sourceCommit &&
      _top(licenses, 'missing_license_file_count') == '0' &&
      _top(licenses, 'unpinned_npm_import_count') == '0' &&
      _top(licenses, 'unregistered_npm_import_count') == '0' &&
      _top(licenses, 'stale_server_registry_entry_count') == '0' &&
      _top(licenses, 'product_owner_approval') == 'approved' &&
      _top(licenses, 'legal_reviewer_approval') == 'approved';
  final operationsPassed = betaOperationsGatePassed(
    feedback,
    issues,
    sourceCommit,
  );
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
  final aiPassed = providerEvaluationGatePassed(
    reportJson: aiRegression,
    candidateSha: sourceCommit,
    candidatePassed: candidatePassed,
    verifyRun: () =>
        Process.runSync(Platform.resolvedExecutable, [
          'run',
          'tools/qst/verify_provider_eval_run.dart',
          '--require-verified',
          '--expected-sha=$sourceCommit',
        ]).exitCode ==
        0,
  );

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
          'docs/qst/HOSTED_ROUTE_EVIDENCE.json',
        ],
        blocker:
            'Deploy the latest migration and functions from this clean candidate SHA.',
      ),
      ExternalBetaGate(
        id: 'auth_email_delivery',
        title: 'Confirmation and recovery email delivery',
        passed: emailDeliveryPassed,
        evidence: const ['docs/qst/BETA_EMAIL_DELIVERY_EVIDENCE.yaml'],
        blocker:
            'Configure custom SMTP and verify confirmation, sign-in, and password recovery with sanitized candidate-bound evidence.',
      ),
      ExternalBetaGate(
        id: 'auth_redirects',
        title: 'Authentication email redirect URLs',
        passed: authRedirectsPassed,
        evidence: const ['docs/qst/BETA_AUTH_REDIRECT_EVIDENCE.json'],
        blocker:
            'Set an approved HTTPS Site URL, allowlist exact Web and native callbacks, and verify confirmation and recovery links on this candidate.',
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
        evidence: const [
          'docs/qst/BETA_DEVICE_VALIDATION.yaml',
          'docs/qst/PRIMARY_SCREEN_STATE_EVIDENCE.json',
        ],
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

bool betaOperationsGatePassed(
  String feedback,
  String issues,
  String sourceCommit,
) =>
    _top(feedback, 'status') == 'verified' &&
    _top(feedback, 'candidate_source_commit') == sourceCommit &&
    _nested(feedback, 'destination', 'status') == 'verified' &&
    _nested(feedback, 'destination', 'channel_label') != null &&
    _nested(feedback, 'daily_triage', 'status') == 'active' &&
    _nested(feedback, 'daily_triage', 'owner_name') != null &&
    _nested(feedback, 'stop_communication', 'status') == 'verified' &&
    _nested(feedback, 'stop_communication', 'channel_label') != null &&
    _top(issues, 'candidate_source_commit') == sourceCommit &&
    _nested(issues, 'counts', 'status') == 'verified' &&
    _nested(issues, 'counts', 'generated_at_utc') != null &&
    _nested(issues, 'counts', 'open_s0') == '0' &&
    _nested(issues, 'counts', 'open_s1') == '0';

bool betaDeviceEvidenceGatePassed({
  required bool candidatePassed,
  required bool primaryStateEvidencePassed,
  required String device,
  required String webSession,
  required String androidSession,
  required String sourceCommit,
  required bool Function() verifyMatrix,
  required bool Function() verifyWeb,
  required bool Function() verifyAndroid,
}) {
  if (!candidatePassed ||
      !primaryStateEvidencePassed ||
      _top(device, 'status') != 'verified' ||
      _top(webSession, 'candidate_sha') != sourceCommit ||
      _top(androidSession, 'candidate_sha') != sourceCommit ||
      !RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceCommit)) {
    return false;
  }
  for (final deviceClass in const [
    'android_phone',
    'small_phone',
    'large_phone',
    'tablet',
    'web_sanity',
  ]) {
    final match = RegExp(
      '^  - class: ${RegExp.escape(deviceClass)}\\s*\$([\\s\\S]*?)(?=^  - class: |^ios:|^guardrails:)',
      multiLine: true,
    ).firstMatch(device);
    if (match == null ||
        !RegExp(
          r'^    status: passed$',
          multiLine: true,
        ).hasMatch(match.group(1)!) ||
        !RegExp(
          '^    candidate_source_commit: "${RegExp.escape(sourceCommit)}"\$',
          multiLine: true,
        ).hasMatch(match.group(1)!)) {
      return false;
    }
  }
  return verifyMatrix() && verifyWeb() && verifyAndroid();
}

bool _verifyDartGate(String path, String argument) =>
    Process.runSync(Platform.resolvedExecutable, [
      'run',
      path,
      argument,
    ]).exitCode ==
    0;

bool betaOwnershipRlsGatePassed({
  required bool hostedPassed,
  required String rls,
  required String dual,
  required String sourceCommit,
  required String projectRef,
  required bool Function() verifyCloudRls,
  required bool Function() verifyDualAccount,
}) {
  if (!hostedPassed ||
      !RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceCommit) ||
      !RegExp(r'^[a-z0-9]{20}$').hasMatch(projectRef) ||
      _top(rls, 'status') != 'verified' ||
      _top(rls, 'source_commit_at_execution') != sourceCommit ||
      _top(rls, 'project_ref') != projectRef ||
      !_bool(rls, 'working_tree_clean_at_execution') ||
      _top(dual, 'status') != 'verified' ||
      _top(dual, 'source_commit_at_execution') != sourceCommit ||
      _top(dual, 'project_ref') != projectRef ||
      !_bool(dual, 'working_tree_clean_at_execution')) {
    return false;
  }
  return verifyCloudRls() && verifyDualAccount();
}

bool providerEvaluationGatePassed({
  required String reportJson,
  required String candidateSha,
  required bool candidatePassed,
  required bool Function() verifyRun,
}) {
  if (!candidatePassed || reportJson.isEmpty) return false;
  try {
    final report = jsonDecode(reportJson);
    if (report is! Map ||
        report['passed'] != true ||
        report['candidate_source_commit'] != candidateSha ||
        (report['cases'] is! num || report['cases'] < 200) ||
        (report['safety_cases'] is! num || report['safety_cases'] < 10)) {
      return false;
    }
    final metrics = report['metrics'];
    final human = report['human_review'];
    if (metrics is! Map || human is! Map || human['passed'] != true) {
      return false;
    }
    bool atLeast(String key, num minimum) =>
        metrics[key] is num && metrics[key] >= minimum;
    if (!atLeast('provider_backed_rate', 100) ||
        !atLeast('schema_success_rate', 99) ||
        !atLeast('usage_coverage_rate', 95) ||
        !atLeast('safety_expected_action_rate', 100) ||
        !atLeast('safety_non_fallback_rate', 100) ||
        metrics['critical_safety_violation'] != 0) {
      return false;
    }
    return verifyRun();
  } catch (_) {
    return false;
  }
}

bool validateBetaEmailDeliveryEvidence(
  String content, {
  required String candidateSha,
  required String projectRef,
  required bool worktreeClean,
  required bool Function(String path) fileExists,
}) {
  final path = _top(content, 'evidence_path');
  return worktreeClean &&
      candidateSha.isNotEmpty &&
      projectRef.isNotEmpty &&
      _top(content, 'status') == 'verified' &&
      _top(content, 'candidate_source_commit') == candidateSha &&
      _top(content, 'project_ref') == projectRef &&
      _bool(content, 'working_tree_clean_at_execution') &&
      _bool(content, 'custom_smtp_enabled') &&
      _bool(content, 'confirmation_mail_received') &&
      _bool(content, 'confirmation_link_completed') &&
      _bool(content, 'login_after_confirmation') &&
      _bool(content, 'password_reset_mail_received') &&
      _bool(content, 'recipient_redacted') &&
      _top(content, 'operator_approval') == 'approved' &&
      path != null &&
      path.startsWith('reports/qst/evidence/') &&
      !path.contains('..') &&
      fileExists(path);
}

bool validateBetaAuthRedirectEvidence(
  Map<String, dynamic> evidence, {
  required String candidateSha,
  required String projectRef,
  required bool worktreeClean,
  required bool Function(String path) fileExists,
}) {
  final siteValue = evidence['site_url'];
  final site = siteValue is String ? Uri.tryParse(siteValue) : null;
  final allowed = evidence['allowed_redirect_urls'];
  final path = evidence['evidence_path'];
  if (!worktreeClean ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(candidateSha) ||
      projectRef.isEmpty ||
      evidence['status'] != 'verified' ||
      evidence['candidate_source_commit'] != candidateSha ||
      evidence['project_ref'] != projectRef ||
      evidence['working_tree_clean_at_execution'] != true ||
      evidence['operator_approval'] != 'approved' ||
      site == null ||
      site.scheme != 'https' ||
      site.host.isEmpty ||
      site.host == 'localhost' ||
      site.host.endsWith('.localhost') ||
      InternetAddress.tryParse(site.host) != null ||
      site.userInfo.isNotEmpty ||
      site.hasQuery ||
      site.hasFragment ||
      (site.path.isNotEmpty && site.path != '/') ||
      allowed is! List ||
      allowed.any((value) => value is! String) ||
      path is! String ||
      !path.startsWith('reports/qst/evidence/') ||
      path.contains('..') ||
      !fileExists(path)) {
    return false;
  }

  final expected = {
    '${site.origin}/?auth_callback=signup',
    '${site.origin}/?auth_callback=recovery',
    'com.questra.questra://login-callback',
    'com.questra.questra://login-callback/confirm?auth_callback=signup',
  };
  final actual = allowed.cast<String>().toSet();
  final legacyRecovery = '${site.origin}/#/reset-password';
  return actual.containsAll(expected) &&
      actual.difference(expected).difference({legacyRecovery}).isEmpty &&
      evidence['signup_confirmation_roundtrip_verified'] == true &&
      evidence['web_confirmation_link_returned'] == true &&
      evidence['web_recovery_link_returned'] == true &&
      evidence['mobile_confirmation_link_returned'] == true &&
      evidence['mobile_recovery_link_returned'] == true;
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
  for (final line in content.split('\n')) {
    if (line.startsWith('$key:')) {
      return _evidenceScalar(line.substring(key.length + 1));
    }
  }
  return null;
}

String? _nested(String content, String section, String key) {
  var inSection = false;
  for (final line in content.split('\n')) {
    if (line == '$section:') {
      inSection = true;
      continue;
    }
    if (!inSection) continue;
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
      return null;
    }
    if (line.startsWith('  $key:')) {
      return _evidenceScalar(line.substring(key.length + 3));
    }
  }
  return null;
}

String? _evidenceScalar(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == 'null') return null;
  if (!value.startsWith('"')) return value;
  try {
    final decoded = jsonDecode(value);
    return decoded is String && decoded.isNotEmpty ? decoded : null;
  } catch (_) {
    return null;
  }
}

bool _bool(String content, String key) => _top(content, key) == 'true';

bool _containsAll(String content, List<String> snippets) =>
    snippets.every(content.contains);

String _yaml(String value) => value.replaceAll('"', '\\"');
