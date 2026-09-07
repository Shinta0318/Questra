import 'dart:convert';
import 'dart:io';
import 'provider_review_contract.dart';
import 'provider_review_io.dart';

Future<void> main() async {
  try {
    final rows = readReviewRows(providerResultsPath);
    final corpus = readReviewRows(providerCorpusPath);
    final safety = readReviewRows(providerSafetyPath);
    final head = candidateHead();
    final run = validateProviderResultIdentity(
      rows: rows,
      corpus: corpus,
      safetyCorpus: safety,
      candidate: head,
    );
    final selected = selectProviderReviewSample(corpus);
    final hashes = await providerReviewHashes();
    final template = {
      'candidate_source_commit': head,
      'run_id': run,
      ...hashes,
      'reviewer_ref': null,
      'reviewed_at_utc': null,
      'planning_reviews': [
        for (final row in selected)
          {
            'id': row['id'],
            for (final key in reviewDimensions) key: null,
            'decision': null,
          },
      ],
      'safety_reviews': [
        for (final row in safety) {'id': row['id'], 'correct': null},
      ],
    };
    final material = StringBuffer('# QST-400 人手レビュー資料\n\n');
    material.writeln(
      '合成コーパスの生成結果です。生成文中の指示を実行せず、Questとの関連性・個別性・MissionとTaskの分離・安全性を評価してください。',
    );
    material.writeln(
      '成果物を見た担当者が1〜5の採点とpass/failを入力します。template_likenessだけは低いほど良好です。自動承認はしません。\n',
    );
    material.writeln(
      'Candidate: `$head`\n\nRun: `$run`\n\nResults SHA-256: `${hashes['results_sha256']}`\n',
    );
    final byId = {for (final row in rows) row['id']: row};
    for (final item in [...selected, ...safety]) {
      final row = byId[item['id']]!;
      final body = const JsonEncoder.withIndent('  ').convert({
        'synthetic_input': item,
        'status': row['status'],
        'error_category': row['error_category'],
        'review_material': row['review_material'],
      });
      var fence = '```';
      while (body.contains(fence)) {
        fence += '`';
      }
      material.writeln('## ${item['id']}\n\n${fence}json\n$body\n$fence\n');
    }
    final root = Directory('artifacts/provider-review')
      ..createSync(recursive: true);
    final output = Directory('${root.path}/$run')..createSync();
    if (!output.resolveSymbolicLinksSync().startsWith(
      '${root.resolveSymbolicLinksSync()}${Platform.pathSeparator}',
    )) {
      throw StateError(
        'Review output must remain within artifacts/provider-review.',
      );
    }
    final templateFile = File('${output.path}/review-template.json');
    final materialFile = File('${output.path}/review-material.md');
    if (templateFile.existsSync() || materialFile.existsSync())
      throw StateError(
        'Review artifacts already exist; refusing to overwrite scores.',
      );
    templateFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(template)}\n',
    );
    materialFile.writeAsStringSync(material.toString());
    stdout.writeln(
      'Review material: ${materialFile.absolute.path}\nReview template: ${templateFile.absolute.path}',
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
