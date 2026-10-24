import 'dart:convert';
import 'dart:io';
import 'candidate_git_state.dart';
import 'provider_review_contract.dart';

const providerResultsPath = 'tools/qst/quest_planning_eval_results.json';
const providerCorpusPath = 'tools/qst/quest_planning_eval_200.json';
const providerSafetyPath = 'tools/qst/quest_planning_safety_eval_cases.json';
const providerHumanPath = 'reports/qst/QST-400-HUMAN-REVIEW.json';

dynamic readReviewJson(String path) =>
    jsonDecode(File(path).readAsStringSync().replaceFirst('\ufeff', ''));
List<JsonMap> readReviewRows(String path) => (readReviewJson(path) as List)
    .map((row) => JsonMap.from(row as Map))
    .toList();

String verifiedCandidateSource() {
  final source = candidateSourceCommit();
  if (!candidateSourceHasOnlyEvidenceCommits(source)) {
    throw StateError('Candidate source has runtime changes in later commits.');
  }
  return source;
}

Future<String> reviewFileHash(String path) async {
  final result = await Process.run(
    Platform.isWindows ? 'certutil' : 'sha256sum',
    Platform.isWindows ? ['-hashfile', path, 'SHA256'] : [path],
    stdoutEncoding: utf8,
  );
  final hash = RegExp(
    r'\b[a-fA-F0-9]{64}\b',
  ).firstMatch(result.stdout.toString())?.group(0)?.toLowerCase();
  if (result.exitCode != 0 || hash == null)
    throw StateError('Unable to hash review evidence.');
  return hash;
}

Future<Map<String, String>> providerReviewHashes({
  String resultsPath = providerResultsPath,
}) async => {
  'results_sha256': await reviewFileHash(resultsPath),
  'corpus_sha256': await reviewFileHash(providerCorpusPath),
  'safety_corpus_sha256': await reviewFileHash(providerSafetyPath),
};

Future<JsonMap> recomputeRecordedReview(
  JsonMap review, {
  String resultsPath = providerResultsPath,
}) async {
  return computeProviderHumanReview(
    input: review,
    rows: readReviewRows(resultsPath),
    corpus: readReviewRows(providerCorpusPath),
    safetyCorpus: readReviewRows(providerSafetyPath),
    candidate: verifiedCandidateSource(),
    hashes: await providerReviewHashes(resultsPath: resultsPath),
    now: DateTime.now().toUtc(),
  );
}
