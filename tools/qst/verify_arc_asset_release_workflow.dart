import 'dart:io';

const decisionPath = 'docs/qst/ARC_ASSET_RELEASE_DECISION.yaml';
const finalizerPath = 'tools/qst/finalize_arc_asset_release.dart';

void main(List<String> arguments) {
  final failures = <String>[];
  final decision = _read(decisionPath, failures);
  final finalizer = _read(finalizerPath, failures);
  for (final snippet in const [
    'runtime_asset_count: 7',
    'complete_set_required: true',
    'chain_record_per_runtime_asset_required: true',
    'exact_hash_match_required: true',
    'product_and_legal_approval_required: true',
    'commercial_distribution_permission_required: true',
    'partial_approval_allowed: false',
    'reference_mockup_bundled: false',
    'failed_apply_restores_previous_manifests: true',
  ]) {
    _expect(decision, snippet, decisionPath, failures);
  }
  for (final snippet in const [
    'Arc release evidence must start from a clean worktree.',
    'Beta candidate manifest is not bound to HEAD.',
    'current_provenance',
    'release_safe_replacement',
    'Missing chain record',
    'commercialDistributionAllowed',
    'previous manifests were restored',
    '--confirm-apply=true',
  ]) {
    _expect(finalizer, snippet, finalizerPath, failures);
  }

  final requireRelease = arguments.contains('--require-release');
  if (requireRelease) {
    final head = _command(['git', 'rev-parse', 'HEAD']).trim();
    for (final snippet in [
      'status: approved',
      'candidate_source_commit: "$head"',
      'working_tree_clean_before_apply: true',
      'approved_runtime_asset_count: 7',
    ]) {
      _expect(decision, snippet, decisionPath, failures);
    }
    if (!RegExp(
      r'^decision_route: (current_provenance|release_safe_replacement)$',
      multiLine: true,
    ).hasMatch(decision)) {
      failures.add('Arc release decision route is not approved.');
    }
    for (final verifier in const [
      'tools/qst/verify_arc_asset_provenance.dart',
      'tools/qst/verify_candidate_asset_package.dart',
    ]) {
      final result = Process.runSync('dart', [
        'run',
        verifier,
        '--require-release',
      ]);
      if (result.exitCode != 0) failures.add(result.stderr.toString().trim());
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Arc asset release workflow verification failed:');
    for (final failure in failures.where((value) => value.isNotEmpty)) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }
  stdout.writeln(
    requireRelease
        ? 'Arc asset release workflow and candidate package passed.'
        : 'Arc asset release workflow is ready; rights evidence remains pending.',
  );
}

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

void _expect(
  String content,
  String snippet,
  String path,
  List<String> failures,
) {
  if (!content.contains(snippet)) failures.add('$path missing: $snippet');
}
