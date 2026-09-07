import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/core/router/route_recovery_screen.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/home/home_screen.dart';
import 'package:questra/features/guild/guild_discovery_screen.dart';
import 'package:questra/features/quest/quest_screen.dart';
import 'package:questra/features/trail/trail_share_screen.dart';
import 'package:questra/widgets/navigation/questra_bottom_navigation.dart';
import 'package:questra/widgets/navigation/questra_navigation_rail.dart';

void main() {
  testWidgets('844x390 landscape uses reachable bottom navigation', (
    tester,
  ) async {
    await _setViewport(tester, const Size(844, 390));
    final harness = await _mountRouter(tester, AppRoutes.home);
    addTearDown(harness.dispose);

    expect(find.byType(QuestraBottomNavigation), findsOneWidget);
    expect(find.byType(QuestraNavigationRail), findsNothing);
    for (final destination in ['ホーム', 'Quest', 'Arc', 'Trail', 'プロフィール']) {
      final semantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((widget) => widget.properties.label == destination);
      expect(semantics, isNotEmpty, reason: '$destination must stay reachable');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact Profile label keeps its full accessible name', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 800));
    final harness = await _mountRouter(
      tester,
      AppRoutes.home,
      textScaler: const TextScaler.linear(2),
    );
    addTearDown(harness.dispose);

    expect(find.text('自分'), findsOneWidget);
    final profileSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .singleWhere((widget) => widget.properties.label == 'プロフィール');
    expect(profileSemantics.properties.button, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard hides cramped navigation instead of overflowing', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    final harness = await _mountRouter(
      tester,
      AppRoutes.home,
      viewInsets: const EdgeInsets.only(bottom: 300),
    );
    addTearDown(harness.dispose);

    expect(find.byType(QuestraBottomNavigation), findsNothing);
    expect(find.byType(QuestraNavigationRail), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown route offers Home and Quest recovery', (tester) async {
    await _setViewport(tester, const Size(390, 800));
    final harness = await _mountRouter(tester, '/route-that-does-not-exist');
    addTearDown(harness.dispose);

    expect(find.byType(RouteRecoveryScreen), findsOneWidget);
    expect(find.text('この航路は見つかりませんでした'), findsOneWidget);
    expect(find.text('ホームへ戻る'), findsOneWidget);
    expect(find.text('Questを確認する'), findsOneWidget);

    await tester.tap(find.text('Questを確認する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(QuestScreen), findsOneWidget);
  });

  testWidgets('direct Guild gate exposes Home and Quest escape routes', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    final harness = await _mountRouter(tester, AppRoutes.guild);
    addTearDown(harness.dispose);

    expect(find.byType(GuildDiscoveryScreen), findsOneWidget);
    expect(find.byTooltip('ホームへ戻る'), findsOneWidget);
    expect(find.text('Questへ戻る'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid shared Trail has an explicit recovery action', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    final harness = await _mountRouter(tester, '/share/trail/invalid-token');
    addTearDown(harness.dispose);

    expect(find.byType(TrailShareScreen), findsOneWidget);
    expect(find.text('このTrailを確認できません'), findsOneWidget);
    expect(find.text('Questraを開く'), findsOneWidget);
    expect(find.byTooltip('ホームへ戻る'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<_RouterHarness> _mountRouter(
  WidgetTester tester,
  String location, {
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
    ],
  );
  final router = container.read(appRouterProvider)..go(location);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: textScaler, viewInsets: viewInsets),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return _RouterHarness(container, router);
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

class _RouterHarness {
  const _RouterHarness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  void dispose() {
    router.dispose();
    container.dispose();
  }
}

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'qst-416-user',
      email: 'navigation@example.invalid',
      nickname: 'Navigator',
      onboardingCompleted: true,
      legalAcceptanceCurrent: true,
    ),
  );
}
