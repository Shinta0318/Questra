import 'dart:convert';
import 'dart:io';
import 'provider_review_contract.dart';
import 'provider_review_io.dart';

const regressionPath = 'reports/qst/QST-256-REGRESSION.json';
const manifestPath = 'docs/qst/PROVIDER_EVAL_RUN.yaml';

Future<void> main(List<String> arguments) async {
  try {
    final paths = arguments
        .where((value) => value.startsWith('--input='))
        .toList();
    if (paths.length != 1)
      throw FormatException('Usage: --input=<human-review.json> is required.');
    final scope = Process.runSync(Platform.resolvedExecutable, [
      'tools/qst/verify_candidate_scope_partition.dart',
      '--phase=evidence',
    ]);
    if (scope.exitCode != 0) throw StateError(scope.stderr.toString());
    final input = JsonMap.from(
      readReviewJson(paths.single.substring(8)) as Map,
    );
    final human = await recomputeRecordedReview(input);
    File(providerHumanPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(human)}\n',
    );
    if (human['passed'] != true)
      throw StateError(
        'Human review did not meet the 85% planning and 100% safety gates.',
      );
    final gate = Process.runSync(Platform.isWindows ? 'powershell' : 'pwsh', [
      '-NoProfile',
      '-File',
      'tools/qst/quest_planning_release_gate.ps1',
      '-ResultsPath',
      providerResultsPath,
      '-HumanReviewPath',
      providerHumanPath,
      '-OutputPath',
      regressionPath,
    ]);
    if (gate.exitCode != 0)
      throw StateError('Automated provider release gate failed.');
    final regression = readReviewJson(regressionPath) as Map;
    if (regression['passed'] != true ||
        regression['candidate_source_commit'] !=
            human['candidate_source_commit']) {
      throw StateError(
        'Automated provider release gate did not pass for current HEAD.',
      );
    }
    // Recheck the files after the subprocess; never bind the review to newer
    // results than the reviewer actually inspected.
    final checked = await recomputeRecordedReview(human);
    if (canonicalReviewJson(checked) != canonicalReviewJson(human))
      throw StateError('Review evidence changed while validating.');
    final rows = readReviewRows(providerResultsPath);
    final pricing = rows.map((row) => row['pricing_version']).toSet();
    if (pricing.length != 1 ||
        pricing.single is! String ||
        !RegExp(r'^[A-Za-z0-9._-]{3,80}$').hasMatch(pricing.single as String)) {
      throw FormatException(
        'Provider results must use one valid pricing version.',
      );
    }
    File(manifestPath).writeAsStringSync('''version: 1
qst: QST-400
status: verified
candidate_source_commit: "${human['candidate_source_commit']}"
run_id: "${human['run_id']}"
executed_at_utc: "${DateTime.now().toUtc().toIso8601String()}"
provider: gemini
planning_case_count: 200
safety_case_count: ${human['safety_review_count']}
human_planning_review_count: ${human['planning_review_count']}
human_safety_review_count: ${human['safety_review_count']}
category_coverage: ${human['category_coverage']}
persona_coverage: ${human['persona_coverage']}
pricing_version: "${pricing.single}"
results_sha256: "${human['results_sha256']}"
corpus_sha256: "${human['corpus_sha256']}"
safety_corpus_sha256: "${human['safety_corpus_sha256']}"
regression_report_sha256: "${await reviewFileHash(regressionPath)}"
human_review_sha256: "${await reviewFileHash(providerHumanPath)}"
automated_gate_passed: true
human_gate_passed: true
guardrails:
  clean_candidate_required: true
  one_run_id_required: true
  fixed_model_prompt_schema_thinking_required: true
  zero_price_assumption_allowed: false
  local_fallback_is_provider_evidence: false
  safety_fallback_allowed: false
  synthetic_corpus_only: true
  raw_user_content_recorded: false
  reviewer_free_text_recorded: false
  failed_gate_allows_distribution: false
''');
    stdout.writeln(
      'Provider evaluation and human review recorded for ${human['candidate_source_commit']}.',
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
