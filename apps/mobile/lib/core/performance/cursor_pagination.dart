class CursorPageRequest {
  const CursorPageRequest({this.after, this.limit = 20});

  final String? after;
  final int limit;

  CursorPageRequest capped({required int maxLimit}) =>
      CursorPageRequest(after: after, limit: limit.clamp(1, maxLimit));
}

class CursorPage<T> {
  const CursorPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  bool get isEmpty => items.isEmpty;
}

class CursorPaginationService {
  const CursorPaginationService();

  CursorPage<T> page<T>({
    required Iterable<T> sortedItems,
    required String Function(T item) cursorOf,
    required CursorPageRequest request,
    int maxLimit = 50,
  }) {
    final safe = request.capped(maxLimit: maxLimit);
    final values = sortedItems.toList(growable: false);
    final start = _startIndex(values, cursorOf, safe.after);
    final pageItems = values
        .skip(start)
        .take(safe.limit)
        .toList(growable: false);
    final nextIndex = start + pageItems.length;
    final hasMore = nextIndex < values.length;
    return CursorPage<T>(
      items: pageItems,
      hasMore: hasMore,
      nextCursor: hasMore && pageItems.isNotEmpty
          ? cursorOf(pageItems.last)
          : null,
    );
  }

  int _startIndex<T>(
    List<T> values,
    String Function(T item) cursorOf,
    String? after,
  ) {
    if (after == null) return 0;
    final index = values.indexWhere((item) => cursorOf(item) == after);
    if (index < 0) return 0;
    return index + 1;
  }
}

String stableDescendingCursor({
  required DateTime createdAt,
  required String id,
}) {
  final utc = createdAt.toUtc().toIso8601String();
  return '$utc:$id';
}
