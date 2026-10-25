import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/safety/quest_safety_service.dart';
import 'package:questra/core/safety/safety_providers.dart';
import 'package:questra/features/arc/arc_screen.dart';

class _UnavailableSafetyService implements QuestSafetyService {
  int attempts = 0;

  @override
  Future<QuestSafetyAssessment> assess(String input) async {
    attempts++;
    return const QuestSafetyAssessment.unavailable();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Arc retries the same input after safety verification fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final safety = _UnavailableSafetyService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [questSafetyServiceProvider.overrideWithValue(safety)],
        child: const MaterialApp(home: ArcScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('arc-chat-input')),
      '料理を学びたい',
    );
    await tester.tap(find.byTooltip('メッセージを送信'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(safety.attempts, 1);
    expect(find.textContaining('安全性を確認できませんでした'), findsOneWidget);

    await tester.tap(find.text('もう一度試す'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(safety.attempts, 2);
  });
}
