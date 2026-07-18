import 'dart:io';

const configPath = 'supabase/config.toml';
const evidencePath = 'docs/qst/BETA_SUPABASE_PROJECT.yaml';
const runbookPath = 'docs/product/supabase_beta_project_bootstrap.md';
const bootstrapPath = 'tools/qst/bootstrap_supabase_beta.ps1';
const aiProviderPath = 'supabase/functions/_shared/ai_provider.ts';

const requiredFunctions = [
  'arc-chat',
  'arc-quest-guide',
  'generate-arc-advice',
  'generate-mission',
  'generate-quest-guides',
  'generate-star-map',
];

const requiredStaticConfig = [
  'project_id = "questra"',
  '[db.migrations]',
  'enabled = true',
  '[db.seed]',
  'enabled = false',
  'minimum_password_length = 8',
];

const requiredEvidenceGuardrails = [
  'storage: server_side_only',
  'values_recorded: false',
  'local_fallback_is_cloud_evidence: false',
  'secret_values_may_be_committed: false',
  'dashboard_schema_changes_allowed: false',
  'require_cloud_verifier_for_completion: true',
];

void main(List<String> arguments) {
  final requireCloud = arguments.contains('--require-cloud');
  final failures = <String>[];

  final config = _readRequired(configPath, failures);
  final evidence = _readRequired(evidencePath, failures);
  final runbook = _readRequired(runbookPath, failures);
  final bootstrap = _readRequired(bootstrapPath, failures);
  final aiProvider = _readRequired(aiProviderPath, failures);
  final gitignore = _readRequired('.gitignore', failures);

  for (final snippet in requiredStaticConfig) {
    _expect(config, snippet, configPath, failures);
  }
  for (final functionName in requiredFunctions) {
    _expect(config, '[functions.$functionName]', configPath, failures);
    final functionBlock = RegExp(
      r'\[functions\.' +
          RegExp.escape(functionName) +
          r'\]\s*\r?\nverify_jwt = true',
    );
    if (!functionBlock.hasMatch(config)) {
      failures.add('$functionName must keep verify_jwt = true.');
    }
    if (!File('supabase/functions/$functionName/index.ts').existsSync()) {
      failures.add('Missing Edge Function source: $functionName');
    }
    _expect(evidence, '- name: $functionName', evidencePath, failures);
  }

  for (final guardrail in requiredEvidenceGuardrails) {
    _expect(evidence, guardrail, evidencePath, failures);
  }
  for (final ignoredPath in [
    'supabase/.temp/',
    'supabase/.branches/',
    'supabase/functions/.env.beta.local',
  ]) {
    _expect(gitignore, ignoredPath, '.gitignore', failures);
  }
  for (final snippet in [
    'supabase link --project-ref',
    'supabase db push',
    'supabase migration list',
    'supabase secrets set',
    'supabase functions deploy',
    '--require-cloud',
  ]) {
    _expect(runbook, snippet, runbookPath, failures);
  }
  for (final snippet in [
    "[switch]\$Apply",
    "'projects', 'list'",
    "'link', '--project-ref'",
    "'db', 'push', '--linked'",
    "'migration', 'list', '--linked'",
    "'secrets', 'set'",
    "'functions', 'deploy'",
    'status: verified',
    'AI_PROVIDER=gemini',
    'GEMINI_API_KEY',
  ]) {
    _expect(bootstrap, snippet, bootstrapPath, failures);
  }

  for (final snippet in [
    'https://generativelanguage.googleapis.com/v1/interactions',
    'GEMINI_API_KEY',
    'gemini-3.5-flash',
    'AI_PROVIDER',
    'OPENAI_API_KEY',
  ]) {
    _expect(aiProvider, snippet, aiProviderPath, failures);
  }
  for (final functionName in ['arc-chat', 'arc-quest-guide']) {
    final source = _readRequired(
      'supabase/functions/$functionName/index.ts',
      failures,
    );
    _expect(
      source,
      '../_shared/ai_provider.ts',
      'supabase/functions/$functionName/index.ts',
      failures,
    );
  }

  final migrations =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  if (migrations.isEmpty) {
    failures.add('No migration files found.');
  } else {
    final latest = migrations.last.uri.pathSegments.last;
    _expect(evidence, 'latest_local: "$latest"', evidencePath, failures);
  }

  final secretValuePatterns = [
    RegExp(r'service_role\s*[:=]\s*\S{20,}', caseSensitive: false),
    RegExp(
      r'openai_api_key\s*[:=]\s*\S*sk-[A-Za-z0-9_-]+',
      caseSensitive: false,
    ),
    RegExp(r'gemini_api_key\s*[:=]\s*\S{20,}', caseSensitive: false),
    RegExp(r'supabase_db_password\s*[:=]\s*\S+', caseSensitive: false),
  ];
  for (final pattern in secretValuePatterns) {
    if (pattern.hasMatch(evidence)) {
      failures.add('Possible secret value found in $evidencePath.');
    }
  }

  if (requireCloud) {
    _verifyCloudEvidence(evidence, migrations, failures);
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Supabase Beta bootstrap verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Supabase Beta bootstrap verification passed.');
  stdout.writeln(
    requireCloud
        ? 'Cloud project, migrations, functions, and secret-name evidence are verified.'
        : 'Static bootstrap contract is ready; cloud evidence is checked separately.',
  );
}

void _verifyCloudEvidence(
  String evidence,
  List<File> migrations,
  List<String> failures,
) {
  if (!RegExp(r'^status: verified$', multiLine: true).hasMatch(evidence)) {
    failures.add('Top-level cloud evidence status must be verified.');
  }
  _expect(evidence, 'migrations:\n  status: applied', evidencePath, failures);
  _expect(evidence, 'secrets:\n  status: verified', evidencePath, failures);

  final candidateCommit = _yamlScalar(evidence, 'candidate_source_commit', 0);
  if (candidateCommit == null ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(candidateCommit)) {
    failures.add('A full 40-character candidate source commit is required.');
  }

  final projectRef = RegExp(
    r'^\s{2}ref:\s*"?([a-z0-9]{20})"?\s*$',
    multiLine: true,
  ).firstMatch(evidence);
  if (projectRef == null) {
    failures.add('A 20-character hosted project ref is required.');
  }
  for (final field in ['region', 'owner', 'linked_at_utc', 'cli_version']) {
    if (_yamlScalar(evidence, field, 2) == null) {
      failures.add('Cloud evidence field is missing: project.$field');
    }
  }
  _expect(evidence, 'access_verified: true', evidencePath, failures);
  if (_yamlScalar(evidence, 'dashboard_evidence', 2) == null) {
    failures.add(
      'Sanitized Supabase Dashboard evidence reference is required.',
    );
  }

  if (migrations.isNotEmpty) {
    final latest = migrations.last.uri.pathSegments.last;
    _expect(evidence, 'remote_head: "$latest"', evidencePath, failures);
  }
  for (final functionName in requiredFunctions) {
    final deployed = RegExp(
      r'- name: ' +
          RegExp.escape(functionName) +
          r'\s*\r?\n\s+status: deployed\s*\r?\n'
              r'\s+deployed_at_utc: (?!null)',
    );
    if (!deployed.hasMatch(evidence)) {
      failures.add('Deployment evidence is missing for $functionName.');
    }
  }
}

String? _yamlScalar(String content, String field, int indent) {
  final prefix = ' ' * indent;
  final match = RegExp(
    '^${RegExp.escape(prefix + field)}:\\s*(.*?)\\s*\$',
    multiLine: true,
  ).firstMatch(content);
  var value = match?.group(1)?.trim();
  if (value == null || value.isEmpty || value == 'null' || value == '""') {
    return null;
  }
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    value = value.substring(1, value.length - 1);
  }
  return value.isEmpty ? null : value;
}

String _readRequired(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing required file: $path');
    return '';
  }
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

void _expect(
  String content,
  String snippet,
  String path,
  List<String> failures,
) {
  if (!content.contains(snippet)) {
    failures.add('Missing "$snippet" in $path.');
  }
}
