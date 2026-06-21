import 'dart:io';

const detailPath = 'docs/qst/FEATURE_EXPANSION_BACKLOG.yaml';
const backlogPath = 'docs/qst/BACKLOG.yaml';
const productBacklogPath = 'docs/product/qst_backlog.md';

const requiredFields = [
  'title:',
  'priority:',
  'status:',
  'dependencies:',
  'goal:',
  'scope:',
  'acceptance:',
  'files_likely_to_change:',
];

void main() {
  final failures = <String>[];
  final detail = _read(detailPath, failures);
  final backlog = _read(backlogPath, failures);
  final productBacklog = _read(productBacklogPath, failures);

  for (var number = 73; number <= 90; number++) {
    final id = 'QST-${number.toString().padLeft(3, '0')}';
    if (!detail.contains('id: $id')) {
      failures.add('Missing $id in $detailPath');
      continue;
    }
    if (!backlog.contains('id: $id')) {
      failures.add('Missing $id in $backlogPath');
    }
    if (!productBacklog.contains('| $id |')) {
      failures.add('Missing $id in $productBacklogPath');
    }

    final start = detail.indexOf('id: $id');
    final next = number < 90
        ? detail.indexOf('id: QST-${(number + 1).toString().padLeft(3, '0')}')
        : detail.length;
    final block = detail.substring(start, next);
    for (final field in requiredFields) {
      if (!block.contains(field)) {
        failures.add('Missing $field for $id in $detailPath');
      }
    }
  }

  for (final forbidden in ['Story as a product concept', 'AI assistant']) {
    if (!detail.contains(forbidden)) {
      failures.add('Missing constraint reference: $forbidden');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Feature expansion backlog verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Feature expansion backlog verification passed.');
  stdout.writeln('Checked QST-073 through QST-090.');
}

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing file: $path');
    return '';
  }
  return file.readAsStringSync();
}
