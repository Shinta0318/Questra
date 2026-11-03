import 'dart:convert';
import 'dart:io';

bool candidateArtifactsVerified(
  String manifest,
  String sourceCommit, {
  bool Function(String path, int bytes, String sha256)? verifyFile,
  String? buildAttestation,
  String? expectedProjectRef,
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
  final hashes = <String, String>{};
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
    hashes[kind] = match.group(3)!;
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
  return kinds.containsAll(const {'web', 'android'}) &&
      candidateBuildAttestationMatches(
        sourceCommit,
        hashes['web']!,
        hashes['android']!,
        attestation: buildAttestation,
        expectedProjectRef: expectedProjectRef,
      );
}

bool candidateBuildAttestationMatches(
  String sourceCommit,
  String webSha256,
  String androidSha256, {
  String? attestation,
  String? expectedProjectRef,
}) {
  if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceCommit) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(webSha256) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(androidSha256)) {
    return false;
  }
  final file = File('artifacts/candidate/questra-build-$sourceCommit.txt');
  final content =
      attestation ?? (file.existsSync() ? file.readAsStringSync() : '');
  final fields = <String, String>{};
  for (final line in const LineSplitter().convert(content)) {
    if (line.isEmpty) continue;
    final separator = line.indexOf('=');
    if (separator <= 0 || fields.containsKey(line.substring(0, separator))) {
      return false;
    }
    fields[line.substring(0, separator)] = line.substring(separator + 1);
  }
  return fields.length == 6 &&
      fields['candidate_sha'] == sourceCommit &&
      fields['build_mode'] == 'connected' &&
      RegExp(r'^[a-z0-9]{20}$').hasMatch(fields['project_ref'] ?? '') &&
      (expectedProjectRef == null ||
          fields['project_ref'] == expectedProjectRef) &&
      fields['web_sha256'] == webSha256 &&
      fields['android_sha256'] == androidSha256 &&
      RegExp(r'^[1-9][0-9]*$').hasMatch(fields['run_id'] ?? '');
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
