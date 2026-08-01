import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_source_reference.dart';
import 'package:questra/features/mission/mission_source_reference_repository.dart';

void main() {
  test('stores HTTPS source and replaces the same URL', () async {
    final repository = InMemoryMissionSourceReferenceRepository();
    final checked = DateTime(2026, 8, 1);
    final source = MissionSourceReference(
      title: '公式ガイド',
      url: Uri.parse('https://example.com/guide'),
      publisher: 'Example',
      checkedAt: checked,
      recheckAfter: checked.add(const Duration(days: 30)),
      isOfficial: true,
    );
    await repository.save('m1', source);
    await repository.save('m1', source);
    expect(await repository.findByMission('m1'), hasLength(1));
  });

  test('rejects an untrusted non-HTTPS source', () async {
    final repository = InMemoryMissionSourceReferenceRepository();
    expect(
      () => repository.save(
        'm1',
        MissionSourceReference(
          title: 'unsafe',
          url: Uri.parse('http://example.com'),
          publisher: 'Example',
          checkedAt: DateTime(2026, 8, 1),
        ),
      ),
      throwsFormatException,
    );
  });
}
