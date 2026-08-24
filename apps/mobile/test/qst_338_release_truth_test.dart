import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/config/supabase_config.dart';

void main() {
  group('release persistence policy', () {
    test('release defaults to production and rejects mock persistence', () {
      expect(
        SupabaseConfig.resolveProduction(environment: '', isReleaseMode: true),
        isTrue,
      );
      expect(
        SupabaseConfig.resolveLocalPersistenceAllowed(
          environment: '',
          mockPersistenceRequested: true,
          isReleaseMode: true,
        ),
        isFalse,
      );
    });

    test('explicit production always rejects local persistence', () {
      expect(
        SupabaseConfig.resolveLocalPersistenceAllowed(
          environment: 'production',
          mockPersistenceRequested: true,
          isReleaseMode: false,
        ),
        isFalse,
      );
    });

    test('release preview requires explicit development and mock flags', () {
      expect(
        SupabaseConfig.resolveLocalPersistenceAllowed(
          environment: 'development',
          mockPersistenceRequested: false,
          isReleaseMode: true,
        ),
        isFalse,
      );
      expect(
        SupabaseConfig.resolveLocalPersistenceAllowed(
          environment: 'development',
          mockPersistenceRequested: true,
          isReleaseMode: true,
        ),
        isTrue,
      );
    });

    test('debug and test builds keep local development available', () {
      expect(
        SupabaseConfig.resolveLocalPersistenceAllowed(
          environment: '',
          mockPersistenceRequested: false,
          isReleaseMode: false,
        ),
        isTrue,
      );
    });

    test('unknown environments fail closed', () {
      expect(
        SupabaseConfig.resolveLocalPersistenceAllowed(
          environment: 'stagin',
          mockPersistenceRequested: true,
          isReleaseMode: false,
        ),
        isFalse,
      );
    });
  });

  test('release capability manifest keeps unshipped claims hidden', () {
    final root =
        Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
        ? Directory.current.parent.parent
        : Directory.current;
    final manifest = File(
      '${root.path}/docs/qst/RELEASE_CAPABILITIES.yaml',
    ).readAsStringSync();
    final storeCopy = File(
      '${root.path}/docs/product/store_listing_draft.md',
    ).readAsStringSync();

    expect(manifest, contains('local_or_mock_persistence: prohibited'));
    expect(manifest, contains('guild:\n    status: hidden_not_shipped'));
    expect(storeCopy, isNot(contains('Guild spaces support')));
    expect(storeCopy, isNot(contains('Guild activity')));
  });
}
