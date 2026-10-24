import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_redirects.dart';

import '../../../tools/qst/external_beta_go_no_go.dart';

void main() {
  const candidateSha = '0123456789abcdef0123456789abcdef01234567';
  const projectRef = 'beta-project';

  Map<String, dynamic> validEvidence() => {
    'status': 'verified',
    'project_ref': projectRef,
    'candidate_source_commit': candidateSha,
    'working_tree_clean_at_execution': true,
    'site_url': 'https://questra.example',
    'allowed_redirect_urls': [
      'https://questra.example/?auth_callback=signup',
      'https://questra.example/?auth_callback=recovery',
      'com.questra.questra://login-callback',
      'com.questra.questra://login-callback/confirm?auth_callback=signup',
    ],
    'signup_confirmation_roundtrip_verified': true,
    'web_confirmation_link_returned': true,
    'web_recovery_link_returned': true,
    'mobile_confirmation_link_returned': true,
    'mobile_recovery_link_returned': true,
    'evidence_path': 'reports/qst/evidence/auth_redirect_receipt.md',
    'operator_approval': 'approved',
  };

  bool evaluate(Map<String, dynamic> evidence, {bool clean = true}) =>
      validateBetaAuthRedirectEvidence(
        evidence,
        candidateSha: candidateSha,
        projectRef: projectRef,
        worktreeClean: clean,
        fileExists: (_) => true,
      );

  test('signup and recovery redirects use the current Web origin', () {
    final base = Uri.parse('https://questra.example/quest?draft=1#/arc');
    expect(
      AuthRedirects.webSignupConfirmation(base),
      'https://questra.example/?auth_callback=signup',
    );
    expect(
      AuthRedirects.webPasswordRecovery(base),
      'https://questra.example/?auth_callback=recovery',
    );
    expect(
      AuthRedirects.nativeAuthCallback,
      'com.questra.questra://login-callback',
    );
    expect(
      AuthRedirects.nativeSignupConfirmation,
      'com.questra.questra://login-callback/confirm?auth_callback=signup',
    );
  });

  test('signup passes an explicit confirmation redirect', () {
    final source = File(
      'lib/features/auth/auth_controller.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('emailRedirectTo: AuthRedirects.signupConfirmation'),
    );
  });

  test('beta redirects require exact candidate-bound link evidence', () {
    expect(evaluate(validEvidence()), isTrue);
    expect(
      evaluate(
        validEvidence()
          ..['allowed_redirect_urls'] = [
            ...validEvidence()['allowed_redirect_urls'] as List<String>,
            'https://questra.example/#/reset-password',
          ],
      ),
      isTrue,
    );
    expect(
      evaluate(
        validEvidence()..['signup_confirmation_roundtrip_verified'] = false,
      ),
      isFalse,
    );
    expect(evaluate(validEvidence(), clean: false), isFalse);
    expect(
      evaluate(validEvidence()..['site_url'] = 'http://localhost:3000'),
      isFalse,
    );
    expect(
      evaluate(validEvidence()..['site_url'] = 'https://127.0.0.1'),
      isFalse,
    );
    expect(
      evaluate(validEvidence()..['allowed_redirect_urls'] = <String>[]),
      isFalse,
    );
    expect(
      evaluate(
        validEvidence()
          ..['allowed_redirect_urls'] = [
            ...validEvidence()['allowed_redirect_urls'] as List<String>,
            'https://*.example.com/**',
          ],
      ),
      isFalse,
    );
    expect(
      evaluate(validEvidence()..['web_recovery_link_returned'] = false),
      isFalse,
    );
    expect(
      evaluate(validEvidence()..['candidate_source_commit'] = 'stale'),
      isFalse,
    );
    expect(
      evaluate(validEvidence()..['evidence_path'] = '../secret.txt'),
      isFalse,
    );
  });
}
