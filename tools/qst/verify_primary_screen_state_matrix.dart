import 'dart:io';

void main() {
  const path = 'docs/qst/PRIMARY_SCREEN_STATE_MATRIX.yaml';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Primary screen state matrix is missing.');
    exitCode = 1;
    return;
  }

  final source = file.readAsStringSync();
  final errors = <String>[];
  const screens = <String, String>{
    'home': '/home',
    'arc': '/arc',
    'quest': '/quest',
    'trail': '/trail',
    'profile': '/profile',
    'onboarding': '/onboarding',
  };
  for (final entry in screens.entries) {
    if (!source.contains('  - id: ${entry.key}\n')) {
      errors.add('Missing screen: ${entry.key}');
    }
    if (!source.contains('    route: ${entry.value}\n')) {
      errors.add('Missing route for ${entry.key}: ${entry.value}');
    }
  }
  for (final token in const [
    'compact_viewport: 390x844',
    'large_text_scale: 2.0',
    'deterministic_japanese_font_required: true',
    'candidate_sha_binding_required: true',
    'physical_evidence_replaced_by_golden: false',
    'ai_generating',
    'ai_fallback',
    'filtered_empty',
    'resumed',
  ]) {
    if (!source.contains(token)) errors.add('Missing contract token: $token');
  }

  final evidencePaths = RegExp(
    r'apps/mobile/test/[^,\]\s]+\.dart',
  ).allMatches(source).map((match) => match.group(0)!).toSet();
  if (evidencePaths.length < 10) {
    errors.add('At least 10 distinct test evidence files are required.');
  }
  for (final evidencePath in evidencePaths) {
    if (!File(evidencePath).existsSync()) {
      errors.add('Missing test evidence: $evidencePath');
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Primary screen state matrix verification passed: '
    '${screens.length} screens, ${evidencePaths.length} test files.',
  );
}
