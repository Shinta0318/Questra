import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('空のTrail画面は初期表示内に作成CTAを一つだけ表示する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TrailScreen())),
    );
    await tester.pump();

    final primaryAction = find.byKey(const ValueKey('trail-primary-create'));
    expect(primaryAction, findsOneWidget);
    expect(find.text('最初のTrailを残す'), findsOneWidget);
    expect(tester.getTopLeft(primaryAction).dy, lessThan(500));
  });

  testWidgets('保存した最初のTrailがすぐTimelineへ反映される', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), '最初の記録');
    await tester.enterText(fields.at(1), '今日の一歩を残した');
    await tester.enterText(fields.at(2), '小さく始められたので、明日も続けたい。');
    await tester.tap(find.text('Trailを保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BottomSheet), findsNothing);
    expect(container.read(trailControllerProvider).single.title, '最初の記録');
    await tester.scrollUntilVisible(
      find.text('最初の記録'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('最初の記録'), findsWidgets);
    expect(find.text('Trail 1件'), findsOneWidget);
    expect(find.text('Trailを残す'), findsOneWidget);
  });

  testWidgets('保存失敗時は入力を保持して再試行できる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trailControllerProvider.overrideWith(_FailingTrailController.new),
        ],
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '消えない入力');
    await tester.enterText(fields.at(1), '失敗時の確認');
    await tester.enterText(fields.at(2), '入力内容を保持したまま再試行する。');
    await tester.tap(find.text('Trailを保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('再試行できます'), findsOneWidget);
    expect(find.text('Trailを保存'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '消えない入力'), findsOneWidget);
  });
}

class _FailingTrailController extends TrailController {
  @override
  List<Trail> build() => const [];

  @override
  Future<bool> addManualTrailAndWait({
    required String title,
    required String summary,
    required String content,
    String? trailId,
    TrailParentContext? parent,
  }) async => false;
}
