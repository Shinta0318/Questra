import 'dart:io';

const notesPath = 'docs/product/beta_release_notes_draft.md';

const requiredSnippets = [
  'Internal Beta',
  '今回試せること',
  '試験中の機能',
  '現在利用できない機能',
  '既知の制約',
  'Betaで確認してほしい航路',
  'Feedback',
  'テストを止める条件',
  'Guildは主なナビゲーションではComing Soon',
  '完了したMissionやQuestの進捗をTrailとして残し',
  'Supabase未接続',
  '外部クラッシュレポートは無効',
  'クリップボードへコピーするだけ',
];

void main() {
  final file = File(notesPath);
  final failures = <String>[];

  if (!file.existsSync()) {
    failures.add('Missing required file: $notesPath');
  } else {
    final content = file.readAsStringSync();
    for (final snippet in requiredSnippets) {
      if (!content.contains(snippet)) {
        failures.add('Missing "$snippet" in $notesPath');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Beta release notes readiness verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta release notes readiness verification passed.');
  stdout.writeln('Checked ready, experimental, unavailable, and stop states.');
}
