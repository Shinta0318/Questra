import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_quick_action.dart';

void main() {
  test('Profile exposes Settings and Feedback through normal navigation', () {
    final source = File(
      'lib/features/profile/profile_screen.dart',
    ).readAsStringSync();
    expect(source, contains('context.push(AppRoutes.settings)'));
    expect(source, contains('context.push(AppRoutes.feedback)'));
    expect(source, contains("tooltip: '設定'"));
  });

  test('Home and Profile reserve space above primary navigation', () {
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    final profile = File(
      'lib/features/profile/profile_screen.dart',
    ).readAsStringSync();
    expect(home, matches(RegExp(r'AppSpacing\.xl,\s*120,', multiLine: true)));
    expect(profile, contains('EdgeInsets.fromLTRB(20, 20, 20, 120)'));
  });

  test('Arc quick actions separate label from typed intent and prompt', () {
    final action = ArcQuickAction.fromLabel('Questを作る');
    expect(action.intent, ArcQuickActionIntent.createQuest);
    expect(action.label, 'Questを作る');
    expect(action.prompt, isNot(action.label));
    expect(action.prompt, contains('相談'));
  });
}
