import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';
import 'package:questra/features/settings/widgets/experience_settings_card.dart';

void main() {
  testWidgets('experience settings expose motion and feedback controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          experienceSettingsRepositoryProvider.overrideWithValue(
            InMemoryExperienceSettingsRepository(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ExperienceSettingsCard()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('体験・演出'), findsOneWidget);
    expect(find.text('Arcアニメーション'), findsOneWidget);
    expect(find.text('触覚フィードバック'), findsOneWidget);
    expect(find.text('効果音'), findsOneWidget);
    expect(find.text('スワイプ操作'), findsOneWidget);
    expect(find.text('省電力モード'), findsOneWidget);
  });
}
