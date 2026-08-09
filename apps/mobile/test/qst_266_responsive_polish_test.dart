import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/arc/arc_screen.dart';
import 'package:questra/features/home/home_screen.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_detail_screen.dart';
import 'package:questra/widgets/navigation/questra_bottom_navigation.dart';

import 'support/fixture_quest_controller.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  final widths = [320.0, 390.0, 430.0];
  final scales = [1.0, 1.3, 2.0];
  final surfaces = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'Arc': () => const ArcScreen(),
    'Quest Detail': () => Consumer(
      builder: (context, ref, child) => QuestDetailScreen(
        questId: ref.watch(questControllerProvider).first.id,
      ),
    ),
  };

  for (final width in widths) {
    for (final scale in scales) {
      for (final surface in surfaces.entries) {
        testWidgets(
          '${surface.key} fits ${width.round()}px at ${scale}x text',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  questControllerProvider.overrideWith(
                    FixtureQuestController.new,
                  ),
                ],
                child: MaterialApp(
                  theme: AppTheme.light,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: surface.value(),
                ),
              ),
            );
            await tester.pump();

            final exception = tester.takeException();
            if (exception is FlutterError) {
              fail(
                '${exception.toStringDeep()}\n${_overflowingRows().join('\n')}',
              );
            }
            expect(exception, isNull);
          },
        );
      }

      testWidgets('Bottom navigation fits ${width.round()}px at ${scale}x', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 180);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              bottomNavigationBar: QuestraBottomNavigation(
                currentIndex: 0,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        for (final key in ['home', 'quest', 'arc', 'trail', 'profile']) {
          expect(tester.getSize(find.byKey(ValueKey('nav-$key'))).height, 58);
        }
      });
    }
  }

  test('primary dark-surface copy meets normal-text AA contrast', () {
    expect(_contrast(AppColors.white, AppColors.deepNavy), greaterThan(4.5));
    expect(_contrast(AppColors.skyBlue, AppColors.deepNavy), greaterThan(4.5));
    expect(_contrast(AppColors.gold, AppColors.deepNavy), greaterThan(4.5));
  });
}

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  return (light + 0.05) / (dark + 0.05);
}

List<String> _overflowingRows() {
  final result = <String>[];
  for (final element in find.byType(Row).evaluate()) {
    final flex = element.renderObject;
    if (flex is! RenderFlex || !flex.hasSize) continue;
    var child = flex.firstChild;
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      if (data.offset.dx + child.size.width > flex.size.width + 0.1) {
        result.add(element.toStringDeep(minLevel: DiagnosticLevel.info));
        break;
      }
      child = data.nextSibling;
    }
  }
  return result;
}
