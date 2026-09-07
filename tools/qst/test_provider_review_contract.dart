import 'dart:convert';
import 'dart:io';
import 'provider_review_contract.dart';

void main() {
  final corpus =
      (jsonDecode(
                File(
                  'tools/qst/quest_planning_eval_200.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<JsonMap>();
  final safety =
      (jsonDecode(
                File(
                  'tools/qst/quest_planning_safety_eval_cases.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<JsonMap>();
  final candidate = 'a' * 40;
  final hashes = {
    'results_sha256': 'b' * 64,
    'corpus_sha256': 'c' * 64,
    'safety_corpus_sha256': 'd' * 64,
  };
  final sample = selectProviderReviewSample(corpus);
  JsonMap clone(JsonMap value) => jsonDecode(jsonEncode(value)) as JsonMap;
  final rows = <JsonMap>[
    for (final item in corpus)
      {
        'id': item['id'],
        'evaluation_type': 'planning',
        'candidate_source_commit': candidate,
        'run_id': '1' * 32,
        'status': 'ok',
        'source_type': 'gemini_interactions',
        'review_material': {
          'version': 1,
          'result_status': 'preview_ready',
          'missions': [
            {'title': 'fixture'},
          ],
        },
      },
    for (final item in safety)
      {
        'id': item['id'],
        'evaluation_type': 'safety',
        'candidate_source_commit': candidate,
        'run_id': '1' * 32,
        'status': 'ok',
        'source_type': 'gemini_interactions',
        'actual_action': item['expected_action'],
        'review_material': {
          'version': 1,
          'assessment': {'action': item['expected_action']},
        },
      },
  ];
  final template = <String, dynamic>{
    'candidate_source_commit': candidate,
    'run_id': '1' * 32,
    ...hashes,
    'reviewer_ref': 'test-reviewer',
    'reviewed_at_utc': '2026-09-01T00:00:00Z',
    'planning_reviews': [
      for (final item in sample)
        {
          'id': item['id'],
          for (final key in reviewDimensions)
            key: key == 'template_likeness' ? 1 : 5,
          'decision': 'pass',
        },
    ],
    'safety_reviews': [
      for (final item in safety) {'id': item['id'], 'correct': true},
    ],
  };
  JsonMap compute(JsonMap input, {List<JsonMap>? data}) =>
      computeProviderHumanReview(
        input: input,
        rows: data ?? rows,
        corpus: corpus,
        safetyCorpus: safety,
        candidate: candidate,
        hashes: hashes,
        now: DateTime.utc(2026, 9, 4),
      );
  var count = 0;
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  void test(String name, void Function() body) {
    body();
    count++;
    stdout.writeln('PASS $name');
  }

  void rejects(void Function() body) {
    var rejected = false;
    try {
      body();
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'Expected invalid evidence to be rejected.');
  }

  test('stratified sample and valid review', () {
    final result = compute(clone(template));
    check(
      sample.length >= 40 &&
          result['passed'] == true &&
          result['category_coverage'] >= 10 &&
          result['persona_coverage'] >= 10,
      'Valid coverage failed.',
    );
  });
  for (final key in hashes.keys) {
    test('stale $key', () {
      final input = clone(template)..[key] = 'e' * 64;
      rejects(() => compute(input));
    });
  }
  test('unknown result cannot replace a corpus case', () {
    final data = rows.map(clone).toList();
    data.first['id'] = 'unknown';
    rejects(() => compute(clone(template), data: data));
  });
  test('duplicate result rejected', () {
    final data = rows.map(clone).toList();
    data[1]['id'] = data.first['id'];
    rejects(() => compute(clone(template), data: data));
  });
  test('future reviewer timestamp rejected', () {
    final input = clone(template)..['reviewed_at_utc'] = '2027-01-01T00:00:00Z';
    rejects(() => compute(input));
  });
  test('duplicate review rejected', () {
    final input = clone(template);
    input['planning_reviews'][1] = input['planning_reviews'][0];
    rejects(() => compute(input));
  });
  test('missing Mission text rejected', () {
    final data = rows.map(clone).toList();
    data.first.remove('review_material');
    rejects(() => compute(clone(template), data: data));
  });
  test('minimum review coverage enforced', () {
    final input = clone(template);
    input['planning_reviews'] = (input['planning_reviews'] as List)
        .take(39)
        .toList();
    rejects(() => compute(input));
  });
  test('scores are integers and not flags', () {
    final input = clone(template);
    input['planning_reviews'][0]['quest_relevance'] = true;
    rejects(() => compute(input));
  });
  test('fabricated aggregate cannot turn bad scores into a pass', () {
    final input = clone(template)..['passed'] = true;
    for (final review in input['planning_reviews']) {
      review['quest_relevance'] = 1;
    }
    final actual = compute(input);
    check(
      actual['passed'] == false && actual['planning_pass_rate'] == 0,
      'Aggregate was trusted.',
    );
    check(
      canonicalReviewJson(actual) != canonicalReviewJson(input),
      'Tampered output was accepted.',
    );
  });
  test('wrong safety action cannot be promoted by reviewer', () {
    final data = rows.map(clone).toList();
    data.last['actual_action'] = 'wrong';
    check(
      compute(clone(template), data: data)['passed'] == false,
      'Incorrect safety decision passed.',
    );
  });
  test('fallback safety decision rejected', () {
    final data = rows.map(clone).toList();
    data.last['source_type'] = 'safety_fallback';
    check(
      compute(clone(template), data: data)['passed'] == false,
      'Fallback counted as safety evidence.',
    );
  });
  test('recomputed summary is stable and excludes free text', () {
    final input = clone(template)..['private_note'] = 'must not be retained';
    final actual = compute(input);
    check(!actual.containsKey('private_note'), 'Free text retained.');
    check(
      canonicalReviewJson(compute(actual)) == canonicalReviewJson(actual),
      'Review recomputation changed valid output.',
    );
  });
  test('preselected case cannot be replaced after seeing results', () {
    final input = clone(template);
    final selectedIds = sample.map((row) => row['id']).toSet();
    final replacement = corpus.firstWhere(
      (row) => !selectedIds.contains(row['id']),
    );
    input['planning_reviews'][0]['id'] = replacement['id'];
    rejects(() => compute(input));
  });
  test('additional passing cases cannot dilute a failing fixed sample', () {
    final input = clone(template);
    final failedCount = (sample.length * .15).floor() + 1;
    for (final review in (input['planning_reviews'] as List).take(
      failedCount,
    )) {
      review['quest_relevance'] = 1;
    }
    final selectedIds = sample.map((row) => row['id']).toSet();
    for (final item in corpus.where(
      (row) => !selectedIds.contains(row['id']),
    )) {
      input['planning_reviews'].add({
        'id': item['id'],
        for (final key in reviewDimensions)
          key: key == 'template_likeness' ? 1 : 5,
        'decision': 'pass',
      });
    }
    final result = compute(input);
    check(
      result['planning_pass_rate'] >= 85 &&
          result['required_sample_pass_rate'] < 85 &&
          result['passed'] == false,
      'Additional cases diluted failed preselected cases.',
    );
  });
  test('additional reviews are allowed without replacing the fixed sample', () {
    final input = clone(template);
    final selectedIds = sample.map((row) => row['id']).toSet();
    final item = corpus.firstWhere((row) => !selectedIds.contains(row['id']));
    input['planning_reviews'].add({
      'id': item['id'],
      for (final key in reviewDimensions)
        key: key == 'template_likeness' ? 1 : 5,
      'decision': 'pass',
    });
    final result = compute(input);
    check(
      result['passed'] == true && result['required_sample_pass_rate'] == 100,
      'Valid additional review was rejected.',
    );
  });
  test('non-provider output cannot count as a passing human case', () {
    final data = rows.map(clone).toList();
    for (final row in data.where(
      (row) => row['evaluation_type'] == 'planning',
    )) {
      row['source_type'] = 'local_fallback';
    }
    check(
      compute(clone(template), data: data)['passed'] == false,
      'Human approval promoted local fallback output.',
    );
  });
  test('candidate mismatch rejected', () {
    final data = rows.map(clone).toList();
    data.first['candidate_source_commit'] = 'e' * 40;
    rejects(() => compute(clone(template), data: data));
  });
  stdout.writeln(
    '$count human review scenarios passed (synthetic fixtures, no provider calls).',
  );
}
