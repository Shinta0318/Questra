class GroupedCollectionIndex<K, V> {
  GroupedCollectionIndex._(this._groups, this.itemCount);

  factory GroupedCollectionIndex.build(
    Iterable<V> values, {
    required K Function(V value) keyOf,
  }) {
    final groups = <K, List<V>>{};
    var itemCount = 0;
    for (final value in values) {
      itemCount += 1;
      (groups[keyOf(value)] ??= <V>[]).add(value);
    }
    return GroupedCollectionIndex._({
      for (final entry in groups.entries)
        entry.key: List.unmodifiable(entry.value),
    }, itemCount);
  }

  final Map<K, List<V>> _groups;
  final int itemCount;

  int get groupCount => _groups.length;

  List<V> valuesFor(K key) => _groups[key] ?? const [];
}
