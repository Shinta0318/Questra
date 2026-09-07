import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/l10n/app_localizations.dart';
import 'package:questra/widgets/forms/questra_modal_sheet.dart';

void main() {
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('opaque surface scrolls above keyboard at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(_Host(dirty: false));
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
      final material = tester.widget<Material>(
        find.byKey(const Key('questra-modal-surface')),
      );
      expect(material.color, AppColors.white);
      expect(find.text('長い末尾'), findsOneWidget);
      await tester.ensureVisible(find.text('長い末尾'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('barrier and close require confirmation for a dirty draft', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(dirty: true));
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('変更を破棄しますか？'), findsOneWidget);
    await tester.tap(find.text('編集を続ける'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('questra-modal-surface')), findsOneWidget);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('破棄して閉じる'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('questra-modal-surface')), findsNothing);
  });

  testWidgets('busy modal blocks close and submit finish closes once', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(dirty: true, busy: true));
    await tester.tap(find.text('開く'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('変更を破棄しますか？'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('successful submission bypasses discard prompt', (tester) async {
    await tester.pumpWidget(_Host(dirty: true));
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    final save = find.text('保存成功');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('変更を破棄しますか？'), findsNothing);
    expect(find.byKey(const Key('questra-modal-surface')), findsNothing);
  });

  testWidgets('discard copy follows the English locale', (tester) async {
    await tester.pumpWidget(_Host(dirty: true, locale: const Locale('en')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard and close'), findsOneWidget);
  });
}

class _Host extends StatelessWidget {
  const _Host({
    required this.dirty,
    this.busy = false,
    this.locale = const Locale('ja'),
  });
  final bool dirty;
  final bool busy;
  final Locale locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Stack(
          children: [
            FilledButton(
              onPressed: () => showQuestraModalSheet<void>(
                context: context,
                builder: (context) => QuestraModalSheet(
                  title: 'Trailを残す',
                  hasUnsavedChanges: () => dirty,
                  isBusy: busy,
                  child: Column(
                    children: [
                      const TextField(),
                      const SizedBox(height: 500),
                      const Text('長い末尾'),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => QuestraModalSheet.finish(context),
                        child: const Text('保存成功'),
                      ),
                    ],
                  ),
                ),
              ),
              child: Text(locale.languageCode == 'ja' ? '開く' : 'Open'),
            ),
          ],
        ),
      ),
    ),
  );
}
