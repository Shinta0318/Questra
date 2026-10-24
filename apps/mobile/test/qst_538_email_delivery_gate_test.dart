import 'package:flutter_test/flutter_test.dart';

import '../../../tools/qst/external_beta_go_no_go.dart';

void main() {
  const candidateSha = '0123456789abcdef0123456789abcdef01234567';
  const projectRef = 'beta-project';
  const verified =
      '''
status: verified
project_ref: beta-project
candidate_source_commit: $candidateSha
working_tree_clean_at_execution: true
custom_smtp_enabled: true
confirmation_mail_received: true
confirmation_link_completed: true
login_after_confirmation: true
password_reset_mail_received: true
recipient_redacted: true
evidence_path: reports/qst/evidence/email_delivery_receipt.md
operator_approval: approved
''';

  bool evaluate(
    String content, {
    String sha = candidateSha,
    bool clean = true,
    bool proofExists = true,
  }) => validateBetaEmailDeliveryEvidence(
    content,
    candidateSha: sha,
    projectRef: projectRef,
    worktreeClean: clean,
    fileExists: (_) => proofExists,
  );

  test('email delivery requires every candidate-bound receipt', () {
    expect(evaluate(verified), isTrue);
    expect(evaluate(verified, clean: false), isFalse);
    expect(evaluate(verified, sha: 'another-candidate'), isFalse);
    expect(evaluate(verified, proofExists: false), isFalse);
    expect(
      evaluate(
        verified.replaceFirst(
          'custom_smtp_enabled: true',
          'custom_smtp_enabled: false',
        ),
      ),
      isFalse,
    );
    expect(
      evaluate(
        verified.replaceFirst(
          'confirmation_mail_received: true',
          'confirmation_mail_received: false',
        ),
      ),
      isFalse,
    );
    expect(
      evaluate(
        verified.replaceFirst(
          'evidence_path: reports/qst/evidence/email_delivery_receipt.md',
          'evidence_path: ../private/receipt.md',
        ),
      ),
      isFalse,
    );
  });
}
