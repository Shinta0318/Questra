import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/onboarding/onboarding_tour_controller.dart';
import 'package:questra/l10n/app_localizations.dart';
import 'package:questra/widgets/onboarding/questra_onboarding_tour.dart';

void main() {
  testWidgets('replay opens on the current screen and Skip restores it', (
    tester,
  ) async {
    await _mount(tester);

    await tester.tap(find.text('設定の内容'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('onboarding-tour-surface')),
      findsOneWidget,
    );
    expect(find.text('Questraへようこそ'), findsOneWidget);
    expect(find.text('設定の内容'), findsOneWidget);

    await tester.tap(find.text('スキップ'));
    await tester.pump();

    expect(find.byKey(const ValueKey('onboarding-tour-surface')), findsNothing);
    expect(find.text('設定の内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('low viewport and 2x text keep close and navigation reachable', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 420));
    await _mount(tester, textScaler: const TextScaler.linear(2));
    await tester.tap(find.text('設定の内容'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('onboarding-tour-scroll')),
      findsOneWidget,
    );
    expect(find.byTooltip('閉じる'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('閉じる'));
    await tester.pump();
    expect(find.byKey(const ValueKey('onboarding-tour-surface')), findsNothing);
  });

  testWidgets('rapid taps advance only one step per frame', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('設定の内容'));
    await tester.pump();

    final next = find.text('次へ');
    await tester.tap(next, warnIfMissed: false);
    await tester.tap(next, warnIfMissed: false);
    await tester.pump();

    expect(find.text('Questを灯す'), findsOneWidget);
    expect(find.text('Missionで航路を決める'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back dismisses the overlay without leaving the screen', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.text('設定の内容'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byKey(const ValueKey('onboarding-tour-surface')), findsNothing);
    expect(find.text('設定の内容'), findsOneWidget);
  });

  testWidgets('all five steps explain Quest, Mission, Task, and Trail', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.text('設定の内容'));
    await tester.pump();

    for (final title in [
      'Questraへようこそ',
      'Questを灯す',
      'Missionで航路を決める',
      'Taskから始める',
      '迷ったらArcへ',
    ]) {
      expect(find.text(title), findsOneWidget);
      if (title != '迷ったらArcへ') {
        await tester.tap(find.text('次へ'));
        await tester.pump();
      }
    }

    await tester.tap(find.text('始める'));
    await tester.pump();
    expect(find.byKey(const ValueKey('onboarding-tour-surface')), findsNothing);
    expect(find.text('設定の内容'), findsOneWidget);
  });

  testWidgets('background tap can never leave a barrier-only state', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.text('設定の内容'));
    await tester.pump();

    await tester.tapAt(const Offset(2, 2));
    await tester.pump();

    expect(find.byKey(const ValueKey('onboarding-tour-surface')), findsNothing);
    expect(find.text('設定の内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: const _TourHarness(),
        ),
      ),
    ),
  );
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

class _TourHarness extends ConsumerWidget {
  const _TourHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingTourControllerProvider);
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(onboardingTourControllerProvider.notifier).replay(),
              child: const Text('設定の内容'),
            ),
          ),
          if (state.isVisible)
            QuestraOnboardingTour(
              key: ValueKey(state.presentationId),
              entryPoint: state.entryPoint,
            ),
        ],
      ),
    );
  }
}
