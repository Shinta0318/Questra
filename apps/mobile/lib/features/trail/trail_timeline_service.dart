import 'trail_model.dart';

class TrailTimelineDay {
  const TrailTimelineDay({required this.dateLabel, required this.trails});

  final String dateLabel;
  final List<Trail> trails;
}

class TrailTimelineService {
  const TrailTimelineService();

  List<TrailTimelineDay> groupByDay(List<Trail> trails) {
    final sorted = [...trails]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = <String, List<Trail>>{};

    for (final trail in sorted) {
      final key = _dateLabel(trail.createdAt);
      groups.putIfAbsent(key, () => []).add(trail);
    }

    return groups.entries
        .map(
          (entry) =>
              TrailTimelineDay(dateLabel: entry.key, trails: entry.value),
        )
        .toList(growable: false);
  }

  String _dateLabel(DateTime value) {
    return '${value.year}/${value.month}/${value.day}';
  }
}
