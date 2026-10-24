import 'dart:io';

import 'candidate_artifacts.dart';

void main() {
  const source = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const webHash =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const androidHash =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  final web = 'artifacts/candidate/questra-web-$source.zip';
  final android = 'artifacts/candidate/questra-android-$source.apk';
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
    verifyFile: (_, _, _) => true,
  )) {
    throw StateError('Artifacts from another source commit passed.');
  }
  if (candidateArtifactsVerified(
    valid,
    source,
    verifyFile: (_, _, _) => false,
  )) {
    throw StateError('Mismatched artifact bytes or hash passed.');
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
