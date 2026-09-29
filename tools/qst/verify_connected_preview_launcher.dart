import 'dart:io';

void main() {
  final failures = <String>[];
  final required = <String, List<String>>{
    'tools/qst/run_connected_preview.ps1': [
      'QUESTRA_PREVIEW_CONFIG',
      'Preview configuration must be stored outside the repository.',
      'Only a Supabase anon client key is allowed.',
      "APP_ENVIRONMENT = 'production'",
      r'ALLOW_MOCK_PERSISTENCE = $false',
      '--dart-define-from-file=',
      'server-side Edge Function',
    ],
    'tools/qst/test_connected_preview.ps1': [
      'publishable-key',
      'secret-key-rejected',
      'service-role-rejected',
      'prohibited-server-secret-name',
      'http-url-rejected',
    ],
    'docs/product/connected_preview_runbook.md': [
      'Supabase Auth',
      'Gemini',
      'リポジトリ外',
      '未配備',
      '認証済み',
    ],
    'docs/qst/BACKLOG.yaml': ['id: QST-417'],
    'reports/qst/QST-417.md': ['状態: ImplementedValidationPending'],
    '.github/workflows/release-gate.yml': [
      'verify_connected_preview_launcher.dart',
      'test_connected_preview.ps1',
    ],
  };

  for (final entry in required.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) {
      failures.add('Missing ${entry.key}');
      continue;
    }
    final content = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!content.contains(snippet)) {
        failures.add('${entry.key} missing "$snippet"');
      }
    }
  }

  final launcher = File(
    'tools/qst/run_connected_preview.ps1',
  ).readAsStringSync();
  if (launcher.contains('GEMINI_API_KEY =') ||
      launcher.contains('SUPABASE_SERVICE_ROLE_KEY =')) {
    failures.add('Launcher must not forward server-side secrets.');
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Connected preview launcher verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Connected preview launcher verification: PASS.');
}
