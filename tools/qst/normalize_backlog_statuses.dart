import 'dart:io';

const backlogPath = 'docs/qst/BACKLOG.yaml';
const normalizedFromQst = 338;

const _mappings = <String, ({String status, String evidence})>{
  'Planned': (status: 'Planned', evidence: 'not_started'),
  'InProgress': (status: 'InProgress', evidence: 'local_partial'),
  'ImplementedFoundation': (status: 'InProgress', evidence: 'local_partial'),
  'Implemented': (status: 'Implemented', evidence: 'local_partial'),
  'ImplementedValidationPending': (
    status: 'Implemented',
    evidence: 'local_partial',
  ),
  'ImplementedExternalEvidencePending': (
    status: 'Implemented',
    evidence: 'external_pending',
  ),
  'Blocked': (status: 'Blocked', evidence: 'external_pending'),
  'Superseded': (status: 'Superseded', evidence: 'not_required'),
  'Validated': (status: 'Validated', evidence: 'local_verified'),
  'Completed': (status: 'Completed', evidence: 'external_verified'),
};

const _evidenceOverrides = <String, String>{
  'QST-417': 'external_pending',
  'QST-418': 'external_pending',
  'QST-419': 'local_verified',
  'QST-420': 'external_pending',
  'QST-421': 'external_pending',
  'QST-422': 'external_pending',
  'QST-423': 'external_pending',
  'QST-424': 'external_pending',
  'QST-425': 'external_pending',
  'QST-426': 'human_approval_pending',
  'QST-427': 'local_partial',
  'QST-428': 'external_pending',
};

void main(List<String> arguments) {
  final checkOnly = arguments.contains('--check');
  final file = File(backlogPath);
  final original = file.readAsStringSync().replaceAll('\r\n', '\n');
  final normalized = _normalize(original);

  if (checkOnly) {
    if (original != normalized) {
      stderr.writeln(
        'Backlog status normalization is stale. Run '
        '`dart run tools/qst/normalize_backlog_statuses.dart`.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln('Backlog status normalization check passed.');
    return;
  }

  file.writeAsStringSync(normalized);
  stdout.writeln('Normalized QST-$normalizedFromQst and later statuses.');
}

String _normalize(String source) {
  final lines = source.split('\n');
  final output = <String>[];
  String? currentId;
  var currentNumber = 0;

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final idMatch = RegExp(r'^  - id: (QST-(\d+))$').firstMatch(line);
    if (idMatch != null) {
      currentId = idMatch.group(1)!;
      currentNumber = int.parse(idMatch.group(2)!);
      output.add(line);
      continue;
    }

    final statusMatch = RegExp(r'^    status: (.+)$').firstMatch(line);
    if (currentNumber >= normalizedFromQst && statusMatch != null) {
      final oldStatus = statusMatch.group(1)!.trim();
      final mapping = _mappings[oldStatus];
      if (mapping == null) {
        throw StateError('$currentId has unmapped status: $oldStatus');
      }
      output.add('    status: ${mapping.status}');
      output.add(
        '    evidence_state: '
        '${_evidenceOverrides[currentId] ?? mapping.evidence}',
      );
      if (index + 1 < lines.length &&
          lines[index + 1].startsWith('    evidence_state: ')) {
        index++;
      }
      continue;
    }

    if (currentNumber >= normalizedFromQst &&
        line.startsWith('    evidence_state: ')) {
      continue;
    }
    output.add(line);
  }
  return output.join('\n');
}
