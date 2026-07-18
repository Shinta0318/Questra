import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/router/app_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/feedback/beta_feedback_model.dart';
import 'package:questra/features/feedback/beta_feedback_screen.dart';
import 'package:questra/features/feedback/beta_feedback_service.dart';

void main() {
  testWidgets('copies a complete structured beta report', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sink = _RecordingFeedbackSink();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          betaFeedbackSinkProvider.overrideWithValue(sink),
          betaFeedbackDestinationProvider.overrideWithValue(
            const BetaFeedbackDestination(channelLabel: 'Questra Beta受付'),
          ),
        ],
        child: const MaterialApp(home: BetaFeedbackScreen()),
      ),
    );
    await tester.pump();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'Questカードを開けない');
    await tester.enterText(fields.at(1), '1. Questを開く\n2. カードを選ぶ');
    await tester.enterText(fields.at(2), 'Quest詳細が表示される');
    await tester.enterText(fields.at(3), '画面が切り替わらない');
    final copyButton = find.text('報告内容をコピー');
    await tester.ensureVisible(copyButton);
    await tester.pump();
    await tester.tap(copyButton);
    await tester.pump();

    expect(sink.report, isNotNull);
    expect(sink.report!.draft.surface, BetaFeedbackSurface.home);
    expect(sink.report!.draft.severity, BetaFeedbackSeverity.s2);
    expect(sink.report!.draft.summary, 'Questカードを開けない');
    expect(find.textContaining('報告内容をコピーしました'), findsOneWidget);
    expect(find.textContaining('Questra Beta受付'), findsWidgets);
  });

  testWidgets('Settings opens the beta feedback route', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go(AppRoutes.settings);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    final entry = find.widgetWithText(FilledButton, 'フィードバックを報告');
    await tester.scrollUntilVisible(
      entry,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(entry);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BetaFeedbackScreen), findsOneWidget);
    expect(find.text('Betaフィードバック'), findsWidgets);
  });
}

class _RecordingFeedbackSink implements BetaFeedbackSink {
  BetaFeedbackReport? report;

  @override
  Future<void> submit(BetaFeedbackReport report) async {
    this.report = report;
  }
}
