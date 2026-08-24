import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../mission/mission_model.dart';

class TaskSuggestion {
  const TaskSuggestion({
    required this.clientId,
    required this.title,
    required this.action,
    required this.purpose,
    required this.doneCondition,
    required this.expectedOutput,
    required this.estimatedEffortMinutes,
    this.dependencyClientIds = const [],
    this.required = true,
    this.confidence = 0.5,
  });

  final String clientId;
  final String title;
  final String action;
  final String purpose;
  final String doneCondition;
  final String expectedOutput;
  final int estimatedEffortMinutes;
  final List<String> dependencyClientIds;
  final bool required;
  final double confidence;
}

abstract interface class TaskGenerationService {
  Future<List<TaskSuggestion>> generateForMission(Mission mission);
}

class LocalTaskGenerationService implements TaskGenerationService {
  const LocalTaskGenerationService();

  @override
  Future<List<TaskSuggestion>> generateForMission(Mission mission) async {
    final action = _firstNonEmpty([
      mission.action,
      mission.description,
      mission.objective,
      mission.title,
    ]);
    final doneCondition = _firstNonEmpty([
      mission.successCondition,
      mission.doneCondition,
      mission.expectedOutcome,
      mission.expectedOutput,
      action,
    ]);
    return [
      TaskSuggestion(
        clientId: 'local-${mission.id}',
        title: _shortTitle(action),
        action: action,
        purpose: _firstNonEmpty([mission.objective, mission.title]),
        doneCondition: doneCondition,
        expectedOutput: _firstNonEmpty([
          mission.expectedOutcome,
          mission.expectedOutput,
          doneCondition,
        ]),
        estimatedEffortMinutes:
            mission.effortEstimate?.activeEffortMinutes ?? 30,
        confidence: 0.65,
      ),
    ];
  }

  String _firstNonEmpty(List<String> values) => values
      .firstWhere(
        (value) => value.trim().isNotEmpty,
        orElse: () => 'このMissionの次の一歩を実行する',
      )
      .trim();

  String _shortTitle(String value) =>
      value.length <= 100 ? value : '${value.substring(0, 99)}…';
}

class SupabaseTaskGenerationService implements TaskGenerationService {
  const SupabaseTaskGenerationService(this.client);

  final SupabaseClient client;

  @override
  Future<List<TaskSuggestion>> generateForMission(Mission mission) async {
    final response = await client.functions.invoke(
      'quest-planning-v2',
      body: {
        'mode': 'expand_tasks',
        'quest_id': mission.questId,
        'mission_id': mission.id,
        'idempotency_key': 'task-expansion:${mission.id}:${const Uuid().v4()}',
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['status'] != 'preview_ready' || data['task_plan'] is! Map) {
      throw StateError('Task候補を準備できませんでした。入力内容は失われていません。');
    }
    final plan = Map<String, dynamic>.from(data['task_plan'] as Map);
    final qualityGate = Map<String, dynamic>.from(
      plan['qualityGate'] as Map? ?? const {},
    );
    final critic = Map<String, dynamic>.from(
      plan['taskCritic'] as Map? ?? const {},
    );
    if (qualityGate['status'] != 'passed' ||
        qualityGate['version'] != 'qst-341-v1' ||
        critic['passed'] != true ||
        (critic['overallScore'] as num? ?? 0) < 85) {
      throw StateError('Task候補の品質確認が完了していません。Missionを保ったまま再試行できます。');
    }
    final suggestions = <TaskSuggestion>[
      for (final raw in (plan['tasks'] as List? ?? const []))
        if (raw is Map) _fromJson(Map<String, dynamic>.from(raw)),
    ];
    if (suggestions.isEmpty) {
      throw StateError('追加できるTask候補がありませんでした。');
    }
    final passedIds = {
      for (final raw in (critic['taskResults'] as List? ?? const []))
        if (raw is Map && raw['clientId'] is String && raw['passed'] == true)
          raw['clientId'] as String,
    };
    if (passedIds.length != suggestions.length ||
        suggestions.any((item) => !passedIds.contains(item.clientId))) {
      throw StateError('Task候補の評価結果が不足しています。Missionを保ったまま再試行できます。');
    }
    return suggestions;
  }

  TaskSuggestion _fromJson(Map<String, dynamic> data) => TaskSuggestion(
    clientId: data['clientId'] as String? ?? '',
    title: data['title'] as String? ?? '',
    action: data['action'] as String? ?? '',
    purpose: data['purpose'] as String? ?? '',
    doneCondition: data['doneCondition'] as String? ?? '',
    expectedOutput: data['expectedOutput'] as String? ?? '',
    estimatedEffortMinutes:
        (data['estimatedEffortMinutes'] as num?)?.round().clamp(1, 1440) ?? 30,
    dependencyClientIds: (data['dependencies'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    required: data['required'] != false,
    confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
  );
}

final taskGenerationServiceProvider = Provider<TaskGenerationService>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseTaskGenerationService(Supabase.instance.client);
  }
  return const LocalTaskGenerationService();
});
