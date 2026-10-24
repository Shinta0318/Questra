import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/config/supabase_config.dart';
import 'package:questra/features/profile/profile_screen.dart';

void main() {
  testWidgets(
    'automatic offline preview is not presented as a signed-in account',
    (tester) async {
      expect(SupabaseConfig.autoEnterLocalMock, isTrue);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileScreen())),
      );
      await tester.pump();

      expect(find.text('開発用プレビュー'), findsOneWidget);
      expect(find.text('実アカウントには接続していません'), findsOneWidget);
      expect(find.text('ログイン不要の一時プレビューです'), findsOneWidget);
      expect(find.text('ログイン中の航路です'), findsNothing);
      expect(find.text('preview@local.questra'), findsNothing);
      expect(find.text('初期設定済み'), findsNothing);
      expect(find.text('ログアウト'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !SupabaseConfig.autoEnterLocalMock,
  );
}
