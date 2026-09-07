import 'dart:io';

const docPath = 'docs/product/japan_wedge_plain_language_pricing.md';

const requiredTokens = [
  'Students',
  'Working adults',
  'Parents',
  '40-60 beginners',
  'AI-resistant users',
  'Quest | 叶えたい目標',
  'Mission | 中間ステップ',
  'Task | 今日できる一歩',
  'Trail | 進んだ記録',
  '¥480/month',
  '¥780/month',
  '¥980/month',
  'No hard paywall',
  'No real billing integration',
  'Premium must never make basic Quest -> Mission -> Task -> Trail progression weaker',
];

void main() {
  final failures = <String>[];
  final doc = File(docPath);
  if (!doc.existsSync()) {
    failures.add('Missing $docPath');
  } else {
    final content = doc.readAsStringSync();
    for (final token in requiredTokens) {
      if (!content.contains(token)) {
        failures.add('$docPath missing token: $token');
      }
    }
  }

  final billingMatches = Directory('apps/mobile/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) {
        final content = file.readAsStringSync().toLowerCase();
        return content.contains('in_app_purchase') ||
            content.contains('revenuecat') ||
            content.contains('stripe') ||
            content.contains('billingclient') ||
            content.contains('paywall');
      })
      .map((file) => file.path)
      .toList(growable: false);

  if (billingMatches.isNotEmpty) {
    failures.add(
      'QST-351 must not add billing/paywall code. Matches: ${billingMatches.join(', ')}',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Japan wedge validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Japan wedge validation passed.');
}
