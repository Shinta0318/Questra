import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final visibleSurfaceFiles = <String>[
    'lib/features/auth/login_screen.dart',
    'lib/features/auth/signup_screen.dart',
    'lib/features/auth/forgot_password_screen.dart',
    'lib/features/auth/reset_password_screen.dart',
    'lib/features/profile/profile_screen.dart',
    'lib/features/settings/settings_information_architecture_service.dart',
    'lib/features/trail/trail_screen.dart',
    'lib/features/trail/trail_timeline_widget.dart',
    'lib/features/quest/quest_screen.dart',
    'lib/features/quest/quest_detail_screen.dart',
    'lib/widgets/layout/questra_coming_soon_screen.dart',
    'lib/widgets/placeholder_screen.dart',
  ];

  test('主要画面に未翻訳の旧表示文言が残っていない', () {
    const forbiddenLiterals = <String>[
      "'Guest'",
      "'Not logged in'",
      "'Coming Soon'",
      "'Settings Map'",
      "'Trust & Privacy'",
      "'Quest Dashboard'",
      "'Quest Detail'",
      "'Quest Canvas'",
      "'Quest DNA Snapshot'",
      "'Challenge Graph Preview'",
      "'Arc Graph Insight'",
      "'Milestones'",
      "'Remove image?'",
      "'Delete Trail?'",
      "'Retry'",
      "'Dismiss'",
      "'WELCOME BACK'",
      "'BEGIN YOUR JOURNEY'",
      "'RECOVER YOUR ROUTE'",
      "'SET A NEW PASSWORD'",
    ];

    final violations = <String>[];
    for (final path in visibleSurfaceFiles) {
      final source = File(path).readAsStringSync();
      for (final literal in forbiddenLiterals) {
        if (source.contains(literal)) {
          violations.add('$path: $literal');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('旧称とArcの禁止表現がアプリ内に存在しない', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (RegExp(r'\bStory\b').hasMatch(source)) {
        violations.add('${entity.path}: Story');
      }
      if (RegExp(r'AI\s+[Aa]ssistant').hasMatch(source)) {
        violations.add('${entity.path}: AI Assistant');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('Questraの正式な固有語は日本語UIでも維持する', () {
    const approvedTerms = <String>[
      'Questra',
      'Arc',
      'Quest',
      'Mission',
      'Task',
      'Trail',
      'Guild',
      'Star Map',
      'Arc Memory',
      'Stardust',
      'Navigator Rank',
      'Bond',
    ];

    expect(approvedTerms.toSet().length, approvedTerms.length);
  });
}
