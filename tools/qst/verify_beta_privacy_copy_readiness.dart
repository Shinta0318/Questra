import 'dart:io';

const noticePath = 'docs/legal/beta_privacy_notice_ja_draft.md';
const reviewPath = 'docs/product/beta_privacy_legal_copy_review.md';
const servicePath =
    'apps/mobile/lib/features/trust/trust_privacy_review_service.dart';

const requiredNoticeSnippets = [
  '保存するデータ',
  'Arcの生成時に処理するデータ',
  'Edge Functionへ送ります',
  'OpenAI API',
  '自動送信',
  '現在利用できない操作',
  '法務確認',
];

const requiredReviewSnippets = [
  'Implementation Audit',
  'Copy Rules',
  'Open Blockers',
  'human legal review',
];

const requiredServiceSnippets = [
  'データとプライバシー',
  'OpenAI API',
  'クリップボードへコピー',
  'クラッシュ情報の外部自動送信は無効',
  'まだ利用できません',
];

void main() {
  final failures = <String>[];
  _checkFile(noticePath, requiredNoticeSnippets, failures);
  _checkFile(reviewPath, requiredReviewSnippets, failures);
  _checkFile(servicePath, requiredServiceSnippets, failures);

  if (failures.isNotEmpty) {
    stderr.writeln('Beta privacy copy readiness verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta privacy copy readiness verification passed.');
  stdout.writeln('Checked stored/processed data, provider, and Beta limits.');
}

void _checkFile(String path, List<String> snippets, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing required file: $path');
    return;
  }

  final content = file.readAsStringSync();
  for (final snippet in snippets) {
    if (!content.contains(snippet)) {
      failures.add('Missing "$snippet" in $path');
    }
  }
}
