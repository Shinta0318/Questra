import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/router/app_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/mission/mission_screen.dart';
import 'package:questra/widgets/navigation/questra_bottom_navigation.dart';
import 'package:questra/widgets/navigation/questra_navigation_rail.dart';
import 'package:questra/widgets/navigation/questra_quick_action_menu.dart';

void main() {
  test('navigation destination order stays aligned with shell branches', () {
    expect(QuestraNavigationDestination.values.map((item) => item.route), [
      AppRoutes.home,
      AppRoutes.quest,
      AppRoutes.trail,
      AppRoutes.guild,
      AppRoutes.arc,
      AppRoutes.profile,
    ]);
  });

  testWidgets('bottom navigation exposes every destination and selection', (
    tester,
  ) async {
    int? selectedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: QuestraBottomNavigation(
            currentIndex: QuestraNavigationDestination.trail.index,
            onDestinationSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    for (final destination in QuestraNavigationDestination.values) {
      expect(find.byKey(ValueKey('nav-${destination.name}')), findsOneWidget);
    }

    final trailSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .singleWhere((widget) => widget.properties.label == 'Trail');
    expect(trailSemantics.properties.selected, isTrue);

    await tester.tap(find.byKey(const ValueKey('nav-arc')));
    expect(selectedIndex, QuestraNavigationDestination.arc.index);
  });

  testWidgets('Mission keeps persistent navigation in the Quest branch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(AppRoutes.mission);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MissionScreen), findsOneWidget);
    expect(find.byType(QuestraBottomNavigation), findsOneWidget);
    final questSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .singleWhere((widget) => widget.properties.label == 'Quest');
    expect(questSemantics.properties.selected, isTrue);
  });

  testWidgets('medium width replaces bottom navigation with a compact rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go(AppRoutes.home);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuestraNavigationRail), findsOneWidget);
    expect(find.byType(QuestraBottomNavigation), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
  });

  testWidgets('expanded width uses the labeled navigation rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go(AppRoutes.home);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuestraNavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    expect(find.text('Questra'), findsWidgets);
  });

  testWidgets('quick action menu exposes core journey actions', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go(AppRoutes.home);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuestraQuickActionMenu), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('questra-quick-action-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('次の航路'), findsOneWidget);
    expect(find.text('Questを始める'), findsOneWidget);
    expect(find.text('Trailを残す'), findsOneWidget);
    expect(find.text('Arcと話す'), findsOneWidget);
    expect(find.text('Guildへ相談'), findsOneWidget);
  });

  testWidgets('quick action can open Quest creation', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go(AppRoutes.home);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('questra-quick-action-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Questを始める'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Questを作成'), findsWidgets);
    expect(find.text('Quest名'), findsOneWidget);
  });
}
