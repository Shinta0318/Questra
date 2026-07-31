import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_source_reference.dart';

void main() {
  test('source freshness expires at its explicit recheck date', () {
    final source = MissionSourceReference(
      title: 'Official guidance',
      url: Uri.parse('https://example.go.jp/guidance'),
      publisher: 'Official publisher',
      checkedAt: DateTime.utc(2026, 1, 1),
      recheckAfter: DateTime.utc(2026, 2, 1),
      isOfficial: true,
    );
    expect(source.isFreshAt(DateTime.utc(2026, 1, 15)), isTrue);
    expect(source.isFreshAt(DateTime.utc(2026, 2, 2)), isFalse);
  });
}
