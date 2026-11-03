import 'dart:io';

import 'candidate_artifacts.dart';

void main() {
  final workflow = File(
    '.github/workflows/release-gate.yml',
  ).readAsStringSync();
  for (final required in [
    "if: github.event_name == 'workflow_dispatch'",
    'BETA_SUPABASE_URL',
    'BETA_SUPABASE_PUBLISHABLE_KEY',
    'run_connected_preview.ps1 -ConfigPath',
    '--dart-define-from-file=',
    'build_mode=disconnected_ci_only',
    'questra-ci-preview-',
  ]) {
    if (!workflow.contains(required)) {
      throw StateError('Connected release workflow is missing $required.');
    }
  }
  if ('BETA_SUPABASE_PUBLISHABLE_KEY'.allMatches(workflow).length != 1) {
    throw StateError('Publishable key must only be scoped to preparation.');
  }
  const source = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const webHash =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const androidHash =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  final web = 'artifacts/candidate/questra-web-$source.zip';
  final android = 'artifacts/candidate/questra-android-$source.apk';
  const attestation =
      '''candidate_sha=$source
build_mode=connected
project_ref=abcdefghijklmnopqrst
web_sha256=$webHash
android_sha256=$androidHash
run_id=12345
''';
  String artifact(String path, String hash) =>
      '  - status: found\n    path: "$path"\n    bytes: 3\n    sha256: "$hash"\n';
  String manifest(String entries) => 'artifacts:\n${entries}guardrails:\n';
  final valid = manifest(
    artifact(web, webHash) + artifact(android, androidHash),
  );
  final checked = <String>[];
  bool verify(String content) => candidateArtifactsVerified(
    content,
    source,
    buildAttestation: attestation,
    verifyFile: (path, bytes, hash) {
      checked.add(path);
      return bytes == 3 &&
          (path == web ? hash == webHash : hash == androidHash);
    },
  );

  if (!verify(valid) || checked.length != 2) {
    throw StateError('Both SHA-bound artifacts must be verified.');
  }
  for (final invalid in [
    manifest(artifact(web, webHash)),
    manifest(artifact(web, webHash) + artifact(web, webHash)),
    valid.replaceFirst(web, '../questra-web-$source.zip'),
    valid.replaceFirst(webHash, androidHash),
    valid.replaceFirst('bytes: 3', 'bytes: 0'),
    valid.replaceFirst('status: found', 'status: not_built'),
    valid.replaceFirst('guardrails:', '  - status: not_built\nguardrails:'),
  ]) {
    if (verify(invalid)) throw StateError('Invalid artifact list passed.');
  }
  if (candidateArtifactsVerified(
    valid,
    'dddddddddddddddddddddddddddddddddddddddd',
    buildAttestation: attestation,
    verifyFile: (_, _, _) => true,
  )) {
    throw StateError('Artifacts from another source commit passed.');
  }
  if (candidateArtifactsVerified(
    valid,
    source,
    buildAttestation: attestation,
    verifyFile: (_, _, _) => false,
  )) {
    throw StateError('Mismatched artifact bytes or hash passed.');
  }
  if (candidateArtifactsVerified(
    valid,
    source,
    buildAttestation: attestation,
    expectedProjectRef: 'zyxwvutsrqponmlkjihg',
    verifyFile: (_, _, _) => true,
  )) {
    throw StateError('Build for a different Supabase project passed.');
  }
  if (candidateArtifactsVerified(
    valid,
    source,
    buildAttestation: '',
    verifyFile: (_, _, _) => true,
  )) {
    throw StateError('Missing build attestation passed.');
  }
  for (final invalid in [
    attestation.replaceFirst(
      'build_mode=connected',
      'build_mode=disconnected_ci_only',
    ),
    attestation.replaceFirst(
      'candidate_sha=$source',
      'candidate_sha=dddddddddddddddddddddddddddddddddddddddd',
    ),
    attestation.replaceFirst('web_sha256=$webHash', 'web_sha256=$androidHash'),
    attestation.replaceFirst(
      'project_ref=abcdefghijklmnopqrst',
      'project_ref=other',
    ),
    '${attestation}run_id=67890\n',
  ]) {
    if (candidateArtifactsVerified(
      valid,
      source,
      buildAttestation: invalid,
      verifyFile: (_, _, _) => true,
    )) {
      throw StateError('Unconnected or mismatched build attestation passed.');
    }
  }

  final directory = Directory.systemTemp.createTempSync('candidate-artifact-');
  try {
    final file = File('${directory.path}/fixture.txt')
      ..writeAsStringSync('abc');
    const abcHash =
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
    if (!candidateArtifactFileMatches(file.path, 3, abcHash) ||
        candidateArtifactFileMatches(file.path, 4, abcHash) ||
        candidateArtifactFileMatches(file.path, 3, webHash)) {
      throw StateError('Real file size and SHA-256 checks failed.');
    }
  } finally {
    directory.deleteSync(recursive: true);
  }
  print('Candidate artifact verification fixtures: PASS.');
}
