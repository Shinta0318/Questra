import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/persistence/persistence_sync_state.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/widgets/feedback/questra_notification.dart';
import 'package:questra/widgets/persistence_sync_banner.dart';

void main() {
  testWidgets('all notification states remain distinct and readable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final type in QuestraNotificationType.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: QuestraNotification(message: '通知本文', type: type),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('通知本文'));
      expect(text.style?.color, AppColors.notificationText);
      expect(text.style?.fontSize, 15);
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(find.byIcon(type.icon), findsOneWidget);
      final node = tester.getSemantics(find.byType(QuestraNotification));
      expect(node.label, contains('${type.semanticLabel}通知: 通知本文'));
    }
    semantics.dispose();
  });

  testWidgets('long Japanese notice wraps at compact width without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: QuestraNotification(
            message: 'Questの保存が完了しました。次のMissionへ進む前に内容を確認できます。',
            type: QuestraNotificationType.success,
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('通知を閉じる'), findsOneWidget);
    final close = tester.getSize(find.byTooltip('通知を閉じる'));
    expect(close.width, greaterThanOrEqualTo(48));
    expect(close.height, greaterThanOrEqualTo(48));
  });

  testWidgets('Quest saved banner prioritizes message and can be dismissed', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PersistenceSyncBanner(
            state: const PersistenceSyncState(
              status: PersistenceSyncStatus.saved,
              message: 'Questを保存しました。',
            ),
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Questを保存しました。'));
    expect(text.style?.color, AppColors.notificationText);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byType(QuestraNotification)).height,
      lessThanOrEqualTo(64),
    );
    await tester.tap(find.byTooltip('通知を閉じる'));
    expect(dismissed, isTrue);
  });

  testWidgets('shared SnackBar keeps automatic timeout and close control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                QuestraSnackBars.message(
                  '情報通知です。',
                  duration: const Duration(milliseconds: 500),
                ),
              ),
              child: const Text('表示'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('表示'));
    await tester.pump();
    expect(find.text('情報通知です。'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    final closeButton = find.ancestor(
      of: find.byIcon(Icons.close),
      matching: find.byType(IconButton),
    );
    final closeSize = tester.getSize(closeButton);
    expect(closeSize.width, greaterThanOrEqualTo(48));
    expect(closeSize.height, greaterThanOrEqualTo(48));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('情報通知です。'), findsNothing);
  });
}
