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
    'Implemented',
    'Validated',
    'Completed',
    'Blocked',
    'Superseded',
  };
  const allowedEvidenceStates = <String>{
    'not_started',
    'local_partial',
    'local_verified',
    'external_pending',
    'external_partial',
    'external_verified',
    'human_approval_pending',
    'human_approved',
    'not_required',
  };
  final lines = backlogFile.readAsLinesSync();
  final seen = <String>{};
  final errors = <String>[];
  String? currentId;
  var currentNumber = 0;
  var hasStatus = false;
  var hasEvidenceState = false;
  var hasEvidence = false;

  void closeEntry() {
    if (currentId == null || currentNumber < 338) return;
    if (!hasStatus) errors.add('$currentId has no status.');
    if (!hasEvidenceState) errors.add('$currentId has no evidence_state.');
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
      hasEvidenceState = false;
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
    final evidenceStateMatch = RegExp(
      r'^    evidence_state: (.+)$',
    ).firstMatch(line);
    if (evidenceStateMatch != null) {
      final evidenceState = evidenceStateMatch.group(1)!.trim();
      hasEvidenceState = true;
      if (!allowedEvidenceStates.contains(evidenceState)) {
        errors.add('$currentId uses unknown evidence_state: $evidenceState');
      }
    }
    if (line.startsWith('    evidence: [')) hasEvidence = true;
  }
  closeEntry();

  final taxonomy = taxonomyFile.readAsStringSync();
  if (!taxonomy.contains('canonical_backlog: $backlogPath')) {
    errors.add('Status taxonomy does not name the canonical backlog.');
  }
  if (!taxonomy.contains('separation_required_from_qst: 338')) {
    errors.add('Status taxonomy does not require evidence separation.');
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Backlog SSOT gate: PASS (${seen.length} QST IDs checked).');
}
