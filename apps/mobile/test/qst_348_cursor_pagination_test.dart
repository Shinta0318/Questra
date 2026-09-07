import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/performance/cursor_pagination.dart';
import 'package:questra/core/performance/performance_limits.dart';

void main() {
  const service = CursorPaginationService();

  test('walks 100+ journey rows without gaps or duplicates', () {
    final rows = List.generate(
      125,
      (index) => _JourneyRow(
        id: 'row-${index.toString().padLeft(3, '0')}',
        createdAt: DateTime.utc(
          2026,
          8,
          24,
          12,
        ).subtract(Duration(minutes: index)),
      ),
    );

    final visited = <String>[];
    String? cursor;
    do {
      final page = service.page<_JourneyRow>(
        sortedItems: rows,
        cursorOf: (row) => row.cursor,
        request: CursorPageRequest(
          after: cursor,
          limit: QuestraPerformanceLimits.journeyPageLimit,
        ),
        maxLimit: QuestraPerformanceLimits.journeyPageMaxLimit,
      );
      visited.addAll(page.items.map((row) => row.id));
      cursor = page.nextCursor;
      if (!page.hasMore) break;
    } while (cursor != null);

    expect(visited, hasLength(rows.length));
    expect(visited.toSet(), hasLength(rows.length));
    expect(visited.first, 'row-000');
    expect(visited.last, 'row-124');
  });

  test('caps oversized page requests and recovers from unknown cursor', () {
    final rows = List.generate(
      12,
      (index) => _JourneyRow(
        id: 'row-$index',
        createdAt: DateTime.utc(2026, 8, 24).subtract(Duration(days: index)),
      ),
    );

    final page = service.page<_JourneyRow>(
      sortedItems: rows,
      cursorOf: (row) => row.cursor,
      request: const CursorPageRequest(after: 'forged-cursor', limit: 999),
      maxLimit: 5,
    );

    expect(page.items.map((row) => row.id), [
      'row-0',
      'row-1',
      'row-2',
      'row-3',
      'row-4',
    ]);
    expect(page.hasMore, isTrue);
  });
}

class _JourneyRow {
  const _JourneyRow({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;

  String get cursor => stableDescendingCursor(createdAt: createdAt, id: id);
}
