import 'verify_supabase_beta_bootstrap.dart' as verifier;

void main() {
  const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const valid =
      '''functions:
  - name: arc-chat
    status: deployed
    deployed_at_utc: "2026-10-18T12:00:00.000Z"
    source_commit: "$sha"
  - name: quest-planning-v2
    status: deployed
    deployed_at_utc: "2026-10-18T12:01:00.000Z"
    source_commit: "$sha"
secrets:
  status: verified
''';
  final names = ['arc-chat', 'quest-planning-v2'];
  void expectValid(String value) {
    final failures = verifier.functionDeploymentEvidenceFailures(
      value,
      sha,
      names,
    );
    if (failures.isNotEmpty) throw StateError('Expected valid: $failures');
  }

  void expectInvalid(String value) {
    final failures = verifier.functionDeploymentEvidenceFailures(
      value,
      sha,
      names,
    );
    if (failures.isEmpty)
      throw StateError('Expected invalid deployment evidence.');
  }

  expectValid(valid);
  expectInvalid(
    valid.replaceFirst('source_commit: "$sha"', 'source_commit: "$otherSha"'),
  );
  expectInvalid(valid.replaceFirst('    source_commit: "$sha"\n', ''));
  expectInvalid(valid.replaceFirst('2026-10-18T12:00:00.000Z', 'not-a-date'));
  expectInvalid(
    valid.replaceFirst('2026-10-18T12:00:00.000Z', '2026-10-18T12:00:00'),
  );
  expectInvalid(valid.replaceFirst('  - name: quest-planning-v2\n', ''));
  expectInvalid(
    valid.replaceFirst('secrets:\n', '''  - name: arc-chat
    status: deployed
    deployed_at_utc: "2026-10-18T12:02:00.000Z"
    source_commit: "$sha"
secrets:
'''),
  );
  print('Supabase function candidate-SHA evidence tests passed.');
}
