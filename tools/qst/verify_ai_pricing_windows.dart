import 'dart:io';

const _migrationDirectory = 'supabase/migrations';
const _pricingSource = 'https://ai.google.dev/gemini-api/docs/pricing';

void main() {
  final failures = <String>[];
  final source = Directory(_migrationDirectory)
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .map((file) => file.readAsStringSync().replaceAll('\r\n', '\n'))
      .join('\n');
  final rates = _ratePattern.allMatches(source).map(_rate).toList();
  final byModel = <String, List<_Rate>>{};
  for (final rate in rates) {
    byModel.putIfAbsent(rate.model, () => []).add(rate);
  }
  for (final entry in byModel.entries) {
    final windows = entry.value..sort((a, b) => a.start.compareTo(b.start));
    if (windows.map((rate) => rate.start).toSet().length != windows.length) {
      failures.add('${entry.key} has a duplicate effective_from.');
    }
    for (var index = 1; index < windows.length; index++) {
      if (windows[index - 1].end != windows[index].start) {
        failures.add(
          '${entry.key} has a gap or overlap before ${windows[index].start.toIso8601String()}.',
        );
      }
    }
    if (windows.last.end != null) {
      failures.add('${entry.key} has no open successor rate.');
    }
  }

  final flash36 = byModel['gemini-3.6-flash'] ?? const <_Rate>[];
  final rollover = flash36.where((rate) => rate.start == DateTime.utc(2027));
  if (rollover.length != 1 ||
      rollover.single.inputRate != 1500000 ||
      rollover.single.outputRate != 7500000) {
    failures.add(
      'Gemini 3.6 Flash 2027 Standard rollover is missing or stale.',
    );
  }
  for (final model in const [
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-pro-preview',
  ]) {
    if (!byModel.containsKey(model)) failures.add('$model has no price rate.');
  }
  for (final snippet in const [
    "default 'USD'",
    "'micros_per_million_tokens'",
    "date '2026-09-13'",
    'ai_model_cost_rates_no_overlap',
    'verify_ai_model_cost_rate_windows',
    'pricing_effective_at',
    'effective_from <= v_row.pricing_effective_at',
  ]) {
    if (!source.contains(snippet))
      failures.add('Missing pricing contract: $snippet');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('AI pricing window verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }
  stdout.writeln(
    'AI pricing window verification passed: ${rates.length} rates across '
    '${byModel.length} models; source $_pricingSource.',
  );
}

final _ratePattern = RegExp(
  r"\(\s*'gemini'\s*,\s*'(gemini-[^']+)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'https://ai\.google\.dev/gemini-api/docs/pricing'\s*,\s*(?:timestamptz\s*)?'([^']+)'\s*,\s*(?:(?:timestamptz\s*)?'([^']+)'|null)",
  multiLine: true,
);

_Rate _rate(RegExpMatch match) => _Rate(
  model: match.group(1)!,
  inputRate: int.parse(match.group(2)!),
  outputRate: int.parse(match.group(3)!),
  start: _parseUtc(match.group(4)!),
  end: match.group(5) == null ? null : _parseUtc(match.group(5)!),
);

DateTime _parseUtc(String value) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    final parts = value.split('.').first.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }
  return DateTime.parse(value).toUtc();
}

class _Rate {
  const _Rate({
    required this.model,
    required this.inputRate,
    required this.outputRate,
    required this.start,
    required this.end,
  });

  final String model;
  final int inputRate;
  final int outputRate;
  final DateTime start;
  final DateTime? end;
}
