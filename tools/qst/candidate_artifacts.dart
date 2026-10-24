import 'dart:convert';
import 'dart:io';

bool candidateArtifactsVerified(
  String manifest,
  String sourceCommit, {
  bool Function(String path, int bytes, String sha256)? verifyFile,
}) {
  if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceCommit)) return false;
  final section = RegExp(
    r'^artifacts:\r?\n([\s\S]*?)^guardrails:',
    multiLine: true,
  ).firstMatch(manifest)?.group(1);
  if (section == null) return false;

  final entry = RegExp(
    r'  - status: found\r?\n'
    r'    path: ("(?:[^"\\]|\\.)*")\r?\n'
    r'    bytes: ([1-9][0-9]*)\r?\n'
    r'    sha256: "([a-f0-9]{64})"(?:\r?\n|$)',
  );
  final matches = entry.allMatches(section).toList();
  if (matches.length != 2 || section.replaceAll(entry, '').trim().isNotEmpty) {
    return false;
  }

  final kinds = <String>{};
  for (final match in matches) {
    final Object? decodedPath;
    try {
      decodedPath = jsonDecode(match.group(1)!);
    } catch (_) {
      return false;
    }
    if (decodedPath is! String) return false;
    final webPath = 'artifacts/candidate/questra-web-$sourceCommit';
    final androidPath = 'artifacts/candidate/questra-android-$sourceCommit.apk';
    final kind =
        decodedPath == '$webPath.zip' || decodedPath == '$webPath.tar.gz'
        ? 'web'
        : decodedPath == androidPath
        ? 'android'
        : null;
    if (kind == null || !kinds.add(kind)) return false;
    final bytes = int.tryParse(match.group(2)!);
    if (bytes == null ||
        !(verifyFile ?? candidateArtifactFileMatches)(
          decodedPath,
          bytes,
          match.group(3)!,
        )) {
      return false;
    }
  }
  return kinds.containsAll(const {'web', 'android'});
}

bool candidateArtifactFileMatches(String path, int bytes, String sha256) {
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() != bytes) return false;
  final result = Process.runSync(
    Platform.isWindows ? 'certutil' : 'sha256sum',
    Platform.isWindows ? ['-hashfile', path, 'SHA256'] : [path],
  );
  if (result.exitCode != 0) return false;
  final actual = RegExp(
    r'\b[a-fA-F0-9]{64}\b',
  ).firstMatch(result.stdout.toString())?.group(0)?.toLowerCase();
  return actual == sha256;
}
