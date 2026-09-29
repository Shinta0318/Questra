import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/router/app_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/arc/arc_screen.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/quest/quest_screen.dart';

void main() {
  test('Arc Quest entry only accepts Quest-scoped return locations', () {
    final location = AppRoutes.arcForQuestCreation();
    final uri = Uri.parse(location);

    expect(uri.path, AppRoutes.arc);
    expect(uri.queryParameters['returnTo'], AppRoutes.quest);
    expect(AppRoutes.safeArcReturnLocation('/quest'), '/quest');
    expect(AppRoutes.safeArcReturnLocation('/quest/quest-1'), '/quest/quest-1');
    expect(AppRoutes.safeArcReturnLocation('/home'), isNull);
    expect(
      AppRoutes.safeArcReturnLocation('https://example.invalid/quest/1'),
      isNull,
    );
  });

  testWidgets('Quest primary CTA enters Arc and returns to Quest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go(AppRoutes.quest);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('ArcとQuestを考える'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ArcScreen), findsOneWidget);
    expect(find.byTooltip('Questへ戻る'), findsOneWidget);
    await tester.tap(find.byTooltip('Questへ戻る'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuestScreen), findsOneWidget);
  });
}

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'qst-504-user',
      email: 'qst-504@example.invalid',
      nickname: 'Navigator',
      onboardingCompleted: true,
      legalAcceptanceCurrent: true,
    ),
  );
}
