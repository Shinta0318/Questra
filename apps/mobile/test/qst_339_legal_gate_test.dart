import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/signup_screen.dart';
import 'package:questra/features/trust/legal_eligibility_screen.dart';
import 'package:questra/features/trust/legal_policy.dart';

class _UnavailableLegalAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'test-user',
      email: 'test@example.com',
      nickname: 'Captain',
      legalAcceptanceCheckAvailable: false,
    ),
    errorMessage: '認証処理を完了できませんでした。',
    errorContext: AuthErrorContext.login,
  );
}

class _PriorSignupConsentAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'test-user',
      email: 'test@example.com',
      nickname: 'Captain',
      priorSignupConsentClaimed: true,
    ),
  );
}

class _PreviouslyUnavailableLegalAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'test-user',
      email: 'test@example.com',
      nickname: 'Captain',
      legalAcceptanceCheckAvailable: false,
    ),
  );
}

class _OutdatedLegalAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'test-user',
      email: 'test@example.com',
      nickname: 'Captain',
      legalPolicyUpdateRequired: true,
      priorSignupConsentClaimed: true,
    ),
  );
}

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

  test('signup evidence needs every current field', () {
    final metadata = Map<String, dynamic>.from(
      QuestraLegalPolicy.acceptance(
        acceptedAt: DateTime.utc(2026, 8, 18),
      ).toAuthMetadata(),
    );
    expect(QuestraLegalPolicy.matchesSignupMetadata(metadata), isTrue);
    expect(
      QuestraLegalPolicy.matchesSignupMetadata(
        Map<String, dynamic>.from(metadata)..remove('legal_accepted_at'),
      ),
      isFalse,
    );
    expect(
      QuestraLegalPolicy.matchesSignupMetadata(
        Map<String, dynamic>.from(metadata)..['terms_version'] = 'old',
      ),
      isFalse,
    );
  });

  test('signup preflight requires a matching active server policy', () {
    final policy = <String, dynamic>{
      'active': true,
      'minimum_age': QuestraLegalPolicy.minimumAge,
      'eligibility_version': QuestraLegalPolicy.eligibilityVersion,
      'terms_version': QuestraLegalPolicy.termsVersion,
      'privacy_version': QuestraLegalPolicy.privacyVersion,
      'ai_disclosure_version': QuestraLegalPolicy.aiDisclosureVersion,
    };
    expect(QuestraLegalPolicy.matchesActiveReleasePolicy(policy), isTrue);
    expect(
      QuestraLegalPolicy.matchesActiveReleasePolicy(
        Map<String, dynamic>.from(policy)..['active'] = false,
      ),
      isFalse,
    );
    expect(QuestraLegalPolicy.matchesActiveReleasePolicy(null), isFalse);
    expect(
      QuestraLegalPolicy.activePolicyState(policy),
      ActiveLegalPolicyState.current,
    );
    expect(
      QuestraLegalPolicy.activePolicyState(null),
      ActiveLegalPolicyState.unavailable,
    );
    expect(
      QuestraLegalPolicy.activePolicyState(
        Map<String, dynamic>.from(policy)..['terms_version'] = 'new-version',
      ),
      ActiveLegalPolicyState.updateRequired,
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
    expect(find.textContaining('Arcの生成機能を確認済み'), findsOneWidget);
  });

  testWidgets(
    'unavailable consent storage is not mistaken for missing consent',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              _UnavailableLegalAuthController.new,
            ),
          ],
          child: const MaterialApp(home: LegalEligibilityScreen()),
        ),
      );

      expect(find.text('接続を確認'), findsOneWidget);
      expect(find.textContaining('もう一度同意する必要はありません'), findsOneWidget);
      expect(find.text('もう一度確認'), findsOneWidget);
      expect(find.text('同意して続ける'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('認証処理を完了できませんでした。'), findsNothing);
    },
  );

  test('one-time acceptance clears a previous unavailable-check state', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          _PreviouslyUnavailableLegalAuthController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .acceptCurrentLegalPolicy(QuestraLegalPolicy.acceptance());

    final profile = container.read(authControllerProvider).profile!;
    expect(profile.legalAcceptanceCurrent, isTrue);
    expect(profile.legalAcceptanceCheckAvailable, isTrue);
    expect(profile.legalPolicyUpdateRequired, isFalse);
  });

  testWidgets('prior signup claim uses one confirmation with a review option', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            _PriorSignupConsentAuthController.new,
          ),
        ],
        child: const MaterialApp(home: LegalEligibilityScreen()),
      ),
    );

    expect(find.text('登録時の確認内容を引き継ぐ'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('確認して続ける'), findsOneWidget);

    await tester.tap(find.text('内容を見直す'));
    await tester.pump();
    expect(find.byType(Checkbox), findsNWidgets(4));
  });

  testWidgets('new server policy never displays the old consent form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_OutdatedLegalAuthController.new),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: LegalEligibilityScreen(),
          ),
        ),
      ),
    );

    expect(find.text('アプリの更新が必要'), findsOneWidget);
    expect(find.text('利用条件が更新されました'), findsOneWidget);
    expect(find.textContaining('古い内容への再同意は必要ありません'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('確認して続ける'), findsNothing);
    expect(find.text('同意して続ける'), findsNothing);
    expect(tester.takeException(), isNull);
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
