import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/experience/experience_settings.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/core/theme/app_gradients.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/core/theme/questra_surface_palette.dart';
import 'package:questra/features/settings/widgets/experience_settings_card.dart';
import 'package:questra/widgets/questra_card.dart';

double contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(foreground, background).computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05));
}

void main() {
  for (final palette in QuestraSurfacePalette.values) {
    test('${palette.name} foreground pairs meet AA', () {
      final surfaces = palette == QuestraSurfacePalette.light
          ? [
              for (final underlay in [Colors.black, AppColors.deepNavy, Colors.white])
                for (final color in AppGradients.glass.colors)
                  Color.alphaBlend(color, underlay),
            ]
          : [palette.background];
      for (final surface in surfaces) {
        expect(
          contrast(palette.foreground, surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(palette.muted, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(palette.action, surface), greaterThanOrEqualTo(4.5));
      }
    });
  }

  test('Workspace nested surfaces and completed text meet AA', () {
    final surface = Color.alphaBlend(
      Colors.white.withValues(alpha: .05),
      QuestraSurfacePalette.dark.background,
    );
    for (final color in [Colors.white, Colors.white70, Colors.white60]) {
      expect(contrast(color, surface), greaterThanOrEqualTo(4.5));
    }
    expect(contrast(AppColors.gold, surface), greaterThanOrEqualTo(3));
  });

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light
        ? AppTheme.light
        : AppTheme.dark;
    for (final width in [360.0, 390.0, 430.0]) {
      testWidgets('surface pairs at $brightness / $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  for (final palette in QuestraSurfacePalette.values)
                    QuestraCard(
                      palette: palette,
                      child: Builder(
                        builder: (context) {
                          final local = Theme.of(context);
                          expect(
                            local.colorScheme.onSurface,
                            palette.foreground,
                          );
                          expect(
                            local.textTheme.bodyMedium?.color,
                            palette.foreground,
                          );
                          expect(
                            DefaultTextStyle.of(context).style.color,
                            palette.foreground,
                          );
                          return Text('${palette.name}: 次の一歩を選んで、旅の記録を残しましょう。');
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings selected and unselected at $brightness / $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              experienceSettingsRepositoryProvider.overrideWithValue(
                InMemoryExperienceSettingsRepository(),
              ),
            ],
            child: MaterialApp(
              theme: theme,
              home: const Scaffold(
                body: SingleChildScrollView(child: ExperienceSettingsCard()),
              ),
            ),
          ),
        );
        await tester.pump();
        final finder = find.byType(SegmentedButton<ArcMotionLevel>);
        final local = Theme.of(tester.element(finder));
        final style = local.segmentedButtonTheme.style!;
        for (final state in [
          <WidgetState>{},
          {WidgetState.selected},
          {WidgetState.hovered},
          {WidgetState.focused},
          {WidgetState.selected, WidgetState.focused},
        ]) {
          final bg = style.backgroundColor!.resolve(state)!;
          final fg = style.foregroundColor!.resolve(state)!;
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
          expect(
            contrast(
              style.side!.resolve(state)!.color,
              QuestraSurfacePalette.dark.background,
            ),
            greaterThanOrEqualTo(3),
          );
        }
        await tester.tap(
          find.descendant(
            of: finder,
            matching: find.text(ArcMotionLevel.values.first.label),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<SegmentedButton<ArcMotionLevel>>(finder).selected,
          {ArcMotionLevel.values.first},
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
