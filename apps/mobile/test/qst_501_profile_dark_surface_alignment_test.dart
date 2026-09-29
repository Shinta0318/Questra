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
      expect(tester.takeException(), isNull);
    },
  );
}
