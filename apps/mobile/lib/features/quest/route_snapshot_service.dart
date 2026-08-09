import 'dart:convert';

import '../mission/mission_model.dart';
import '../task/task_model.dart';
import 'quest_model.dart';

class RouteSnapshotConflict {
  const RouteSnapshotConflict({required this.changedEntityIds});

  final List<String> changedEntityIds;

  bool get isStale => changedEntityIds.isNotEmpty;

  String get message => isStale ? '提案後に進捗が更新されました。最新の航路で提案を作り直してください。' : '';
}

class RouteSnapshotService {
  const RouteSnapshotService();

  Map<String, Object?> capture({
    required Quest quest,
    required Iterable<Mission> missions,
    required Iterable<QuestraTask> tasks,
  }) {
    final missionRows =
        missions
            .where((mission) => mission.questId == quest.id)
            .map(
              (mission) => <String, Object?>{
                'id': mission.id,
                'status': mission.status.storageKey,
                'progressPercent': mission.progressPercent,
                'sortOrder': mission.sortOrder,
                'isToday': mission.isToday,
                'routeState': mission.routeState.name,
              },
            )
            .toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final taskRows =
        tasks
            .where((task) => task.questId == quest.id)
            .map(
              (task) => <String, Object?>{
                'id': task.id,
                'missionId': task.missionId,
                'status': task.status.storageKey,
                'orderIndex': task.orderIndex,
                'dependencyIds': [...task.dependencyIds]..sort(),
                'scheduledDate': _dateKey(task.scheduledDate),
                'dueDate': _dateKey(task.dueDate),
              },
            )
            .toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return {
      'snapshotVersion': 1,
      'quest': {'id': quest.id, 'targetDate': _dateKey(quest.targetDate)},
      'missions': missionRows,
      'tasks': taskRows,
    };
  }

  RouteSnapshotConflict compare(
    Map<String, Object?> expected,
    Map<String, Object?> current,
  ) {
    final changed = <String>[];
    if (_canonical(expected['quest']) != _canonical(current['quest'])) {
      changed.add('quest');
    }
    _compareRows(expected['missions'], current['missions'], 'mission', changed);
    _compareRows(expected['tasks'], current['tasks'], 'task', changed);
    return RouteSnapshotConflict(changedEntityIds: changed);
  }

  void _compareRows(
    Object? expectedValue,
    Object? currentValue,
    String prefix,
    List<String> changed,
  ) {
    final expected = _rowsById(expectedValue);
    final current = _rowsById(currentValue);
    for (final id in {...expected.keys, ...current.keys}) {
      if (_canonical(expected[id]) != _canonical(current[id])) {
        changed.add('$prefix:$id');
      }
    }
  }

  Map<String, Object?> _rowsById(Object? value) {
    final rows = value is List ? value : const [];
    return {
      for (final row in rows.whereType<Map>())
        if (row['id'] is String) row['id'] as String: row,
    };
  }

  String _canonical(Object? value) => jsonEncode(_normalize(value));

  Object? _normalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _normalize(value[key])};
    }
    if (value is List) return value.map(_normalize).toList(growable: false);
    if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      return value.substring(0, 10);
    }
    return value;
  }

  static String? _dateKey(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
}
