import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/widgets/navigation/questra_route_back_button.dart';

void main() {
  testWidgets('direct destination uses its documented safe parent', (
    tester,
  ) async {
    final router = _router('/settings');
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('プロフィールへ戻る'), findsOneWidget);
    await tester.tap(find.byTooltip('プロフィールへ戻る'));
    await tester.pumpAndSettle();

    expect(find.text('Profile body'), findsOneWidget);
  });

  testWidgets('pushed destination returns through the active stack', (
    tester,
  ) async {
    final router = _router('/profile');
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/settings');
    await tester.pumpAndSettle();

    expect(find.byTooltip('戻る'), findsOneWidget);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    expect(find.text('Profile body'), findsOneWidget);
  });

  testWidgets('plain MaterialApp does not require a GoRouter ancestor', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuestraRouteBackButton(
            fallbackRoute: '/profile',
            fallbackTooltip: 'プロフィールへ戻る',
          ),
        ),
      ),
    );

    expect(find.byTooltip('プロフィールへ戻る'), findsOneWidget);
    await tester.tap(find.byType(QuestraRouteBackButton));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('navigation SSOT names the five primary destinations and fallbacks', () {
    final document = File(
      '../../docs/architecture/mvp-navigation.md',
    ).readAsStringSync();

    expect(
      document,
      contains('1. Home\n2. Quest\n3. Arc\n4. Trail\n5. Profile'),
    );
    expect(document, contains('| Settings | Profile |'));
    expect(document, contains('| Data Rights | Settings |'));
    expect(document, contains('| Guild pilot | Home |'));
    expect(document, isNot(contains('5. Mission')));
  });
}

GoRouter _router(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Profile body'))),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: const QuestraRouteBackButton(
              fallbackRoute: '/profile',
              fallbackTooltip: 'プロフィールへ戻る',
            ),
            title: const Text('Settings'),
          ),
          body: const Center(child: Text('Settings body')),
        ),
      ),
    ],
  );
}
