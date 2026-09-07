import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/settings/settings_information_architecture_service.dart';
import 'package:questra/features/settings/settings_screen.dart';

void main() {
  test('settings index reports truthful local and connected capabilities', () {
    const service = SettingsInformationArchitectureService();
    final local = service.buildOverview();
    final connected = service.buildOverview(remotePersistenceConnected: true);

    expect(local.heading, '設定メニュー');
    expect(local.sections, hasLength(SettingsSectionType.values.length));
    expect(
      _section(local, SettingsSectionType.dataRequest).statusLabel,
      '端末内のみ',
    );
    expect(
      _section(connected, SettingsSectionType.dataRequest).statusLabel,
      '利用できます',
    );
    expect(
      local.sections.every((section) => section.destination.isNotEmpty),
      isTrue,
    );
    expect(
      local.sections.map((section) => section.statusLabel),
      isNot(contains('確認する')),
    );
  });

  testWidgets('settings anchored section supports a direct link', (
    tester,
  ) async {
    final router = _router(
      initialLocation: AppRoutes.settingsSection('planning'),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      AppRoutes.settingsSection('planning'),
    );
    expect(find.text('航路に使える時間'), findsOneWidget);
  });

  testWidgets('settings index opens a real destination and back restores it', (
    tester,
  ) async {
    final router = _router(initialLocation: AppRoutes.settings);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('設定メニュー'), findsOneWidget);
    expect(find.text('設定ガイド'), findsNothing);
    expect(find.textContaining('RLS'), findsNothing);

    final memoryAction = find.byKey(
      const ValueKey('settings_action_/settings/arc-memory'),
    );
    await tester.ensureVisible(memoryAction);
    await tester.tap(memoryAction);
    await tester.pumpAndSettle();
    expect(find.text('Arc Memory destination'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.settings);
    expect(find.text('設定メニュー'), findsOneWidget);
  });
}

SettingsSectionOverview _section(
  SettingsInformationArchitecture overview,
  SettingsSectionType type,
) => overview.sections.firstWhere((section) => section.type == type);

GoRouter _router({String initialLocation = '/profile-test'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/profile-test',
        builder: (context, state) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('open_settings'),
              onPressed: () => context.push(AppRoutes.settings),
              child: const Text('設定'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.settings}/section/:section',
        builder: (context, state) =>
            SettingsScreen(initialSection: state.pathParameters['section']),
      ),
      GoRoute(
        path: AppRoutes.arcMemory,
        builder: (context, state) =>
            const Scaffold(body: Text('Arc Memory destination')),
      ),
      GoRoute(
        path: AppRoutes.dataRights,
        builder: (context, state) =>
            const Scaffold(body: Text('Data destination')),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (context, state) =>
            const Scaffold(body: Text('Feedback destination')),
      ),
    ],
  );
}
