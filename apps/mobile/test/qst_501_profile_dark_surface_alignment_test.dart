import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/questra_surface_palette.dart';
import 'package:questra/features/profile/profile_screen.dart';
import 'package:questra/widgets/questra_card.dart';

void main() {
  testWidgets(
    'Profile cards use the shared dark journey surface at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      for (final key in const [
        'profile-account-card',
        'profile-bond-card',
        'profile-rank-card',
        'profile-journey-card',
      ]) {
        final finder = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(
          finder,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.widget<QuestraCard>(finder).palette,
          QuestraSurfacePalette.dark,
        );
      }
      expect(find.text('プロフィール'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-account-card')),
        -240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final accountTitle = tester.widget<Text>(find.text('ゲスト'));
      expect(accountTitle.style?.color, QuestraSurfacePalette.dark.foreground);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-bond-card')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('ArcとのBond'), findsOneWidget);
      expect(find.text('0 / 100'), findsOneWidget);
      expect(find.text('Arc Bond'), findsNothing);

      final bondTitle = tester.widget<Text>(find.text('ArcとのBond'));
      final bondScore = tester.widget<Text>(find.text('0 / 100'));
      expect(bondTitle.style?.color, QuestraSurfacePalette.dark.foreground);
      expect(bondScore.style?.color, QuestraSurfacePalette.dark.foreground);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-rank-card')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final rankTitle = tester.widget<Text>(
        find.text('Stardust / Navigator Rank'),
      );
      expect(rankTitle.style?.color, QuestraSurfacePalette.dark.foreground);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-journey-card')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final journeyTitle = tester.widget<Text>(find.text('旅の現在地'));
      expect(journeyTitle.style?.color, QuestraSurfacePalette.dark.foreground);
      expect(tester.takeException(), isNull);
    },
  );
}
