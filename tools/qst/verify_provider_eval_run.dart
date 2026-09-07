import 'dart:convert';
import 'dart:io';

const manifestPath = 'docs/qst/PROVIDER_EVAL_RUN.yaml';
const recorderPath = 'tools/qst/record_provider_eval_human_review.dart';
const resultsPath = 'tools/qst/quest_planning_eval_results.json';
const regressionPath = 'reports/qst/QST-256-REGRESSION.json';
const humanPath = 'reports/qst/QST-400-HUMAN-REVIEW.json';

Future<void> main(List<String> arguments) async {
  final failures = <String>[];
  final manifest = _read(manifestPath, failures);
  final recorder =
      _read(recorderPath, failures) +
      _read('tools/qst/provider_review_contract.dart', failures);
  for (final snippet in const [
    'provider: gemini',
    'clean_candidate_required: true',
    'one_run_id_required: true',
    'fixed_model_prompt_schema_thinking_required: true',
    'zero_price_assumption_allowed: false',
    'local_fallback_is_provider_evidence: false',
    'safety_fallback_allowed: false',
    'synthetic_corpus_only: true',
    'reviewer_free_text_recorded: false',
    'failed_gate_allows_distribution: false',
  ]) {
    _expect(manifest, snippet, manifestPath, failures);
  }
  for (final snippet in const [
    'At least 40 planning cases require human review.',
    'Every safety corpus case requires human review.',
    'at least 10 categories and 10 personas',
    'planningPassRate >= 85',
    'safetyPass',
    'quest_planning_release_gate.ps1',
  ]) {
    _expect(recorder, snippet, recorderPath, failures);
  }

  if (arguments.contains('--require-verified')) {
    final humanCheck = Process.runSync(Platform.resolvedExecutable, [
      'tools/qst/verify_provider_human_review.dart',
    ]);
    if (humanCheck.exitCode != 0)
      failures.add(
        'Human review output bindings and recomputed scores failed.',
      );
    final head = _command(['git', 'rev-parse', 'HEAD']).trim();
    for (final snippet in [
      'status: verified',
      'candidate_source_commit: "$head"',
      'planning_case_count: 200',
      'safety_case_count: 10',
      'automated_gate_passed: true',
      'human_gate_passed: true',
    ]) {
      _expect(manifest, snippet, manifestPath, failures);
    }
    final expectedHashes = <String, String>{
      resultsPath: _scalar(manifest, 'results_sha256') ?? '',
      regressionPath: _scalar(manifest, 'regression_report_sha256') ?? '',
      humanPath: _scalar(manifest, 'human_review_sha256') ?? '',
    };
    for (final entry in expectedHashes.entries) {
      if (!File(entry.key).existsSync()) {
        failures.add('Missing provider evidence: ${entry.key}');
      } else if (entry.value != await _sha256(entry.key)) {
        failures.add('Provider evidence hash mismatch: ${entry.key}');
      }
    }
    if (File(regressionPath).existsSync()) {
      final report = jsonDecode(File(regressionPath).readAsStringSync());
      if (report is! Map || report['passed'] != true) {
        failures.add('Automated provider regression report did not pass.');
      }
    }
    if (File(humanPath).existsSync()) {
      final review = jsonDecode(File(humanPath).readAsStringSync());
      if (review is! Map ||
          review['passed'] != true ||
          (review['planning_review_count'] as num? ?? 0) < 40 ||
          (review['safety_review_count'] as num? ?? 0) < 10) {
        failures.add('Human provider review did not pass required coverage.');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Provider evaluation run verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    arguments.contains('--require-verified')
        ? 'Provider evaluation run, human review, and hashes passed.'
        : 'Provider evaluation execution contract is ready; live run remains pending.',
  );
}

String? _scalar(String content, String key) => RegExp(
  '^${RegExp.escape(key)}:\\s*"?([^"\\n]+)"?\\s*\$',
  multiLine: true,
).firstMatch(content)?.group(1)?.trim();

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing $path');
    return '';
  }
  return file.readAsStringSync();
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) {
    stderr.writeln(result.stderr);
    exit(1);
  }
  return result.stdout.toString();
}

Future<String> _sha256(String path) async {
  final command = Platform.isWindows ? 'certutil' : 'sha256sum';
  final args = Platform.isWindows ? ['-hashfile', path, 'SHA256'] : [path];
  final result = await Process.run(command, args);
  final hash = RegExp(
    r'\b[a-fA-F0-9]{64}\b',
  ).firstMatch(result.stdout.toString())?.group(0)?.toLowerCase();
  return hash ?? '';
}

void _expect(
  String content,
  String snippet,
  String path,
  List<String> failures,
) {
  if (!content.contains(snippet)) failures.add('$path missing: $snippet');
}
