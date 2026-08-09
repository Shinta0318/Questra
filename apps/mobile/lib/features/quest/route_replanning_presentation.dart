import 'route_replanning_model.dart';

String routeChangeTargetLabel(RouteChangeItem item) {
  if (item.targetTaskId != null) return 'Task';
  if (item.targetMissionId != null) return 'Mission';
  return 'Quest';
}

String routeChangeActionLabel(RouteChangeAction action) => switch (action) {
  RouteChangeAction.add => '追加',
  RouteChangeAction.remove => '削除',
  RouteChangeAction.replace => '置き換え',
  RouteChangeAction.reorder => '順序変更',
  RouteChangeAction.split => '分割',
  RouteChangeAction.merge => '統合',
  RouteChangeAction.reschedule => '日程変更',
  RouteChangeAction.reestimate => '再評価',
  RouteChangeAction.pause => '一時停止',
  RouteChangeAction.resume => '再開',
};

String routeChangeDiffLabel(RouteChangeItem item) {
  String values(Map<String, Object?> data) => data.entries
      .map((entry) => '${_fieldLabel(entry.key)}: ${_valueLabel(entry.value)}')
      .join(' / ');
  final before = values(item.beforeData);
  final after = values(item.afterData);
  return '変更前 ${before.isEmpty ? "なし" : before}\n'
      '変更後 ${after.isEmpty ? "なし" : after}';
}

String _fieldLabel(String key) => switch (key) {
  'targetDate' => 'Quest期限',
  'scheduledDate' => '予定日',
  'dueDate' => '期限',
  'orderIndex' => '順序',
  'title' => '名称',
  'action' => '行動',
  'status' => '状態',
  'tasks' => 'Task',
  'missions' => 'Mission',
  'estimatedDays' => '推定日数',
  'requiresAiReevaluation' => '航路の再評価',
  _ => key,
};

String _valueLabel(Object? value) {
  if (value == null) return 'なし';
  if (value is bool) return value ? 'はい' : 'いいえ';
  if (value is List) return '${value.length}件';
  return value.toString();
}
