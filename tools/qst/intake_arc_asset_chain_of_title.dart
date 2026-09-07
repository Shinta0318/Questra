import 'dart:convert';
import 'dart:io';

const outputDirectory = 'docs/qst/arc_asset_chain_of_title';

Future<void> main(List<String> arguments) async {
  final recordArgument = arguments.where(
    (argument) => argument.startsWith('--record='),
  );
  if (recordArgument.length != 1) {
    _fail(
      'Usage: dart run tools/qst/intake_arc_asset_chain_of_title.dart --record=<review-record.json>',
    );
  }
  final input = File(recordArgument.single.substring('--record='.length));
  if (!input.existsSync()) _fail('Review record does not exist.');
  final decoded = jsonDecode(input.readAsStringSync());
  if (decoded is! Map) _fail('Review record must be a JSON object.');
  final record = Map<String, dynamic>.from(decoded);
  _rejectSensitiveFields(record);

  for (final key in [
    'schemaVersion',
    'assetPath',
    'assetSha256',
    'sourceKind',
    'sourceEvidenceRef',
    'creatorController',
    'creationContext',
    'termsName',
    'termsVersion',
    'termsReference',
    'productReviewRef',
    'productDecision',
    'legalReviewRef',
    'legalDecision',
    'reviewedUsage',
    'reviewedAtUtc',
  ]) {
    final value = record[key];
    if (value == null || value.toString().trim().isEmpty) {
      _fail('Review record is missing $key.');
    }
  }
  if (record['schemaVersion'] != 1) _fail('Unsupported record schemaVersion.');
  if (record['productDecision'] != 'approved' ||
      record['legalDecision'] != 'approved') {
    _fail('Both Product and Legal decisions must be approved before intake.');
  }
  final commercial = record['commercialDistributionAllowed'];
  if (commercial != true) {
    _fail('Commercial app distribution must be explicitly allowed.');
  }
  final assetPath = record['assetPath'] as String;
  if (!assetPath.startsWith('apps/mobile/assets/characters/arc/') &&
      !assetPath.startsWith('apps/mobile/assets/mockups/')) {
    _fail('Asset path is outside the controlled Arc asset roots.');
  }
  final asset = File(assetPath);
  if (!asset.existsSync()) _fail('Reviewed Arc asset does not exist.');
  final actualHash = await _sha256(assetPath);
  if (record['assetSha256'] != actualHash) {
    _fail('Review record hash does not match the current Arc asset.');
  }
  final reviewedUsage = record['reviewedUsage'];
  if (reviewedUsage is! List || reviewedUsage.isEmpty) {
    _fail('reviewedUsage must contain at least one approved channel.');
  }

  Directory(outputDirectory).createSync(recursive: true);
  final output = File('$outputDirectory/$actualHash.json');
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(record)}\n',
  );
  stdout.writeln('Arc chain-of-title record accepted for $actualHash.');
}

void _rejectSensitiveFields(Object? value, [String path = 'record']) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final normalized = key.toLowerCase();
      if (normalized.contains('secret') ||
          normalized.contains('password') ||
          normalized.contains('token') ||
          normalized.contains('signature') ||
          normalized.contains('privateprompt')) {
        _fail(
          'Sensitive field is not permitted in provenance record: $path.$key',
        );
      }
      _rejectSensitiveFields(entry.value, '$path.$key');
    }
  } else if (value is List) {
    for (var index = 0; index < value.length; index++) {
      _rejectSensitiveFields(value[index], '$path[$index]');
    }
  }
}

Future<String> _sha256(String path) async {
  final result = Platform.isWindows
      ? await Process.run('certutil', ['-hashfile', path, 'SHA256'])
      : await Process.run('sha256sum', [path]);
  if (result.exitCode != 0) _fail('Unable to hash Arc asset.');
  final match = RegExp(
    r'([a-fA-F0-9]{64})',
  ).firstMatch(result.stdout.toString());
  if (match == null) _fail('Arc asset hash output is invalid.');
  return match.group(1)!.toLowerCase();
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
