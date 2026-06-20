import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/config/supabase_config.dart';
import '../arc_memory/arc_memory_model.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

class ArcChatMessage {
  const ArcChatMessage({
    required this.text,
    required this.fromArc,
    required this.createdAt,
  });

  final String text;
  final bool fromArc;
  final DateTime createdAt;
}

class ArcChatContext {
  const ArcChatContext({
    required this.activeQuests,
    required this.recentMissions,
    required this.recentTrails,
    required this.memories,
  });

  final List<Quest> activeQuests;
  final List<Mission> recentMissions;
  final List<Trail> recentTrails;
  final List<ArcMemory> memories;
}

class ArcChatResponse {
  const ArcChatResponse({
    required this.message,
    required this.sourceType,
    this.quickActions = const [],
  });

  final String message;
  final String sourceType;
  final List<String> quickActions;
}

abstract interface class ArcChatService {
  Future<ArcChatResponse> send({
    required String userMessage,
    required List<ArcChatMessage> history,
    required ArcChatContext context,
  });
}

class LocalArcChatService implements ArcChatService {
  const LocalArcChatService();

  @override
  Future<ArcChatResponse> send({
    required String userMessage,
    required List<ArcChatMessage> history,
    required ArcChatContext context,
  }) async {
    final quest = context.activeQuests.isEmpty
        ? null
        : context.activeQuests.first;
    final trail = context.recentTrails.isEmpty
        ? null
        : context.recentTrails.first;
    final questText = quest == null ? '今見えている星' : '「${quest.title}」';
    final trailText = trail == null
        ? 'まだ残していないTrail'
        : '「${trail.title}」のTrail';

    return ArcChatResponse(
      message:
          'おかえり、キャプテン。\n$userMessage という気持ちを受け取ったよ。$questTextへ向かう航路は、$trailTextを手がかりに少しずつ澄んでいく。\n今日はひとつだけ、小さく進める星を選ぼう。',
      sourceType: 'local_fallback',
      quickActions: const ['次のMissionを選ぶ', '最近のTrailを振り返る', '小さな一歩に分ける'],
    );
  }
}

class SupabaseArcChatService implements ArcChatService {
  const SupabaseArcChatService({
    required this.client,
    this.fallback = const LocalArcChatService(),
  });

  final SupabaseClient client;
  final ArcChatService fallback;

  @override
  Future<ArcChatResponse> send({
    required String userMessage,
    required List<ArcChatMessage> history,
    required ArcChatContext context,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return fallback.send(
        userMessage: userMessage,
        history: history,
        context: context,
      );
    }

    try {
      final response = await client.functions.invoke(
        'arc-chat',
        body: {
          'message': userMessage,
          'history': history
              .take(10)
              .map(
                (message) => {
                  'role': message.fromArc ? 'arc' : 'user',
                  'text': message.text,
                },
              )
              .toList(growable: false),
          'context': {
            'active_quests': context.activeQuests
                .take(3)
                .map(
                  (quest) => {
                    'id': quest.id,
                    'title': quest.title,
                    'description': quest.description,
                    'progress': quest.progress,
                    'category': quest.category,
                  },
                )
                .toList(growable: false),
            'recent_missions': context.recentMissions
                .take(5)
                .map(
                  (mission) => {
                    'id': mission.id,
                    'quest_id': mission.questId,
                    'title': mission.title,
                    'status': mission.status.storageKey,
                  },
                )
                .toList(growable: false),
            'recent_trails': context.recentTrails
                .take(5)
                .map(
                  (trail) => {
                    'id': trail.id,
                    'quest_id': trail.questId,
                    'mission_id': trail.missionId,
                    'title': trail.title,
                    'summary': trail.summary,
                    'trail_type': trail.trailType.storageKey,
                  },
                )
                .toList(growable: false),
            'memories': context.memories
                .take(5)
                .map(
                  (memory) => {
                    'id': memory.id,
                    'title': memory.title,
                    'content': memory.content,
                    'importance_score': memory.importanceScore,
                    'memory_type': memory.memoryType.storageKey,
                  },
                )
                .toList(growable: false),
          },
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      return ArcChatResponse(
        message: data['message'] as String? ?? _fallbackMessage,
        sourceType: data['source_type'] as String? ?? 'arc_chat',
        quickActions:
            (data['quick_actions'] as List?)?.cast<String>() ?? const [],
      );
    } catch (_) {
      return fallback.send(
        userMessage: userMessage,
        history: history,
        context: context,
      );
    }
  }

  static const _fallbackMessage = '星雲が少しざわついているみたい。今は小さな一歩だけ一緒に選ぼう。';
}
