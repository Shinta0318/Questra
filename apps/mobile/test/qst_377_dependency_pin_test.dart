import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;

  test('all Edge Function npm imports are exact and registered', () {
    final functions = Directory('${repo.path}/supabase/functions');
    final imports = <String>{};
    for (final file
        in functions
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.ts'))) {
      imports.addAll(
        RegExp(
          r'''["'](npm:[^"']+)["']''',
        ).allMatches(file.readAsStringSync()).map((match) => match.group(1)!),
      );
    }
    final registry =
        jsonDecode(
              File(
                '${repo.path}/tools/qst/server_dependency_registry.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final registered = (registry['dependencies'] as List)
        .map((entry) => (entry as Map<String, dynamic>)['specifier'])
        .toSet();

    expect(imports, isNotEmpty);
    for (final specifier in imports) {
      expect(
        RegExp(r'@(\d+\.\d+\.\d+)(?:["/]|$)').hasMatch(specifier),
        isTrue,
        reason: '$specifier must use an exact version',
      );
      expect(registered, contains(specifier));
    }
  });

  test('dependency evidence records a closed machine-verifiable inventory', () {
    final manifest = File(
      '${repo.path}/docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml',
    ).readAsStringSync();
    expect(manifest, contains('status: generated_review_pending'));
    expect(manifest, contains('missing_license_file_count: 0'));
    expect(manifest, contains('unpinned_npm_import_count: 0'));
    expect(manifest, contains('unregistered_npm_import_count: 0'));
    expect(manifest, contains('stale_server_registry_entry_count: 0'));
    expect(manifest, contains('legal_reviewer_approval: pending'));
  });

  test('dependency evidence binds HEAD only for an approved release', () {
    final verifier = File(
      '${repo.path}/tools/qst/verify_dependency_notices.dart',
    ).readAsStringSync();
    expect(verifier, contains('has no valid source commit'));
    expect(verifier, contains('if (requireRelease)'));
    expect(
      verifier,
      contains('Release dependency evidence is not bound to current HEAD.'),
    );
  });
}
