import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/signup_screen.dart';
import 'package:questra/features/trust/legal_policy.dart';

void main() {
  test('current legal acceptance is versioned and region-bound', () {
    final acceptance = QuestraLegalPolicy.acceptance(
      acceptedAt: DateTime.utc(2026, 8, 18),
    );

    expect(acceptance.isCurrent, isTrue);
    expect(acceptance.regionCode, 'JP');
    expect(acceptance.minimumAgeConfirmed, isTrue);
    expect(
      acceptance.toAuthMetadata(),
      containsPair('terms_version', QuestraLegalPolicy.termsVersion),
    );
    expect(
      acceptance.toAuthMetadata(),
      containsPair('minimum_age_confirmed', true),
    );
  });

  testWidgets('signup collects eligibility before personal account fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignupScreen())),
    );
    await tester.pump();

    expect(find.text('入力を始める前に'), findsOneWidget);
    expect(find.text('メールアドレス'), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(4));

    for (var index = 0; index < 4; index++) {
      final checkbox = find.byType(Checkbox).at(index);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
    }

    final continueButton = find.text('アカウント情報を入力');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump();

    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('ログインID'), findsOneWidget);
    expect(find.textContaining('AI処理を確認済み'), findsOneWidget);
  });

  test(
    'migration validates versions server-side and keeps evidence append-only',
    () {
      final root =
          Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
          ? Directory.current.parent.parent
          : Directory.current;
      final migration = File(
        '${root.path}/supabase/migrations/'
        '202608180001_versioned_legal_eligibility_gate.sql',
      ).readAsStringSync();

      expect(migration, contains('legal_acceptance_required'));
      expect(migration, contains('accept_current_legal_policy'));
      expect(migration, contains("region_code = requested_region and active"));
      expect(
        migration,
        contains('revoke insert, update, delete on public.legal_acceptances'),
      );
      expect(migration, contains("source in ('signup', 'account_gate')"));
    },
  );
}
