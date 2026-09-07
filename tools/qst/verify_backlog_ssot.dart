import 'dart:io';

void main() {
  const backlogPath = 'docs/qst/BACKLOG.yaml';
  const taxonomyPath = 'docs/qst/QST_STATUS_TAXONOMY.yaml';
  final backlogFile = File(backlogPath);
  final taxonomyFile = File(taxonomyPath);
  if (!backlogFile.existsSync() || !taxonomyFile.existsSync()) {
    stderr.writeln('Canonical backlog or status taxonomy is missing.');
    exitCode = 1;
    return;
  }

  const allowed = <String>{
    'Planned',
    'InProgress',
    'ImplementedFoundation',
    'Implemented',
    'ImplementedValidationPending',
    'ImplementedExternalEvidencePending',
    'Blocked',
    'Superseded',
  };
  final lines = backlogFile.readAsLinesSync();
  final seen = <String>{};
  final errors = <String>[];
  String? currentId;
  var currentNumber = 0;
  var hasStatus = false;
  var hasEvidence = false;

  void closeEntry() {
    if (currentId == null || currentNumber < 338) return;
    if (!hasStatus) errors.add('$currentId has no status.');
    if (!hasEvidence) errors.add('$currentId has no evidence list.');
  }

  for (final line in lines) {
    final idMatch = RegExp(r'^  - id: QST-(\d+)$').firstMatch(line);
    if (idMatch != null) {
      closeEntry();
      currentNumber = int.parse(idMatch.group(1)!);
      currentId = 'QST-${idMatch.group(1)}';
      if (!seen.add(currentId)) errors.add('Duplicate QST ID: $currentId');
      hasStatus = false;
      hasEvidence = false;
      continue;
    }
    if (currentId == null || currentNumber < 338) continue;
    final statusMatch = RegExp(r'^    status: (.+)$').firstMatch(line);
    if (statusMatch != null) {
      final status = statusMatch.group(1)!.trim();
      hasStatus = true;
      if (!allowed.contains(status)) {
        errors.add('$currentId uses non-canonical status: $status');
      }
    }
    if (line.startsWith('    evidence: [')) hasEvidence = true;
  }
  closeEntry();

  final taxonomy = taxonomyFile.readAsStringSync();
  if (!taxonomy.contains('canonical_backlog: $backlogPath')) {
    errors.add('Status taxonomy does not name the canonical backlog.');
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Backlog SSOT gate: PASS (${seen.length} QST IDs checked).');
}
