import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/router/app_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/mission/mission_screen.dart';
import 'package:questra/widgets/navigation/questra_bottom_navigation.dart';

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
}
