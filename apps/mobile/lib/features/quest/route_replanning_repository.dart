import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;

import '../../core/config/supabase_config.dart';
import 'route_replanning_model.dart';

final routeReplanningRepositoryProvider = Provider<RouteReplanningRepository>((
  ref,
) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseRouteReplanningRepository(Supabase.instance.client);
  }
  return InMemoryRouteReplanningRepository();
});

abstract interface class RouteReplanningRepository {
  Future<void> saveProposal(RouteChangeProposal proposal);
  Future<void> resolveProposal(
    String proposalId,
    RouteProposalStatus status, {
    List<String> acceptedItemIds = const [],
  });
  Future<RouteMutationResult> applyProposal({
    required RouteChangeProposal proposal,
    required List<String> acceptedItemIds,
  });
  Future<RouteMutationResult> rollbackProposal(String proposalId);
  Future<List<RouteChangeProposal>> findByQuest(String questId);
  Future<void> recordProgressEvent({
    required String questId,
    required String missionId,
    required String eventType,
    required String eventKey,
    Map<String, Object?> metadata = const {},
  });
}

class InMemoryRouteReplanningRepository implements RouteReplanningRepository {
  final List<RouteChangeProposal> _proposals = [];

  @override
  Future<void> saveProposal(RouteChangeProposal proposal) async {
    _proposals.removeWhere((item) => item.id == proposal.id);
    _proposals.add(proposal);
  }

  @override
  Future<List<RouteChangeProposal>> findByQuest(String questId) async {
    return _proposals
        .where((item) => item.questId == questId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> resolveProposal(
    String proposalId,
    RouteProposalStatus status, {
    List<String> acceptedItemIds = const [],
  }) async {
    final index = _proposals.indexWhere((item) => item.id == proposalId);
    if (index >= 0) {
      _proposals[index] = _proposals[index].copyWith(status: status);
    }
  }

  @override
  Future<RouteMutationResult> applyProposal({
    required RouteChangeProposal proposal,
    required List<String> acceptedItemIds,
  }) async {
    final status = acceptedItemIds.length == proposal.items.length
        ? RouteProposalStatus.accepted
        : RouteProposalStatus.partiallyAccepted;
    await resolveProposal(
      proposal.id,
      status,
      acceptedItemIds: acceptedItemIds,
    );
    return RouteMutationResult(
      proposalId: proposal.id,
      questId: proposal.questId,
      status: status,
      persistedAtomically: false,
      routeVersionId: proposal.routeVersionId,
    );
  }

  @override
  Future<RouteMutationResult> rollbackProposal(String proposalId) async {
    final proposal = _proposals
        .where((item) => item.id == proposalId)
        .firstOrNull;
    if (proposal == null) {
      throw StateError('航路変更案が見つかりません。');
    }
    await resolveProposal(proposalId, RouteProposalStatus.rolledBack);
    return RouteMutationResult(
      proposalId: proposalId,
      questId: proposal.questId,
      status: RouteProposalStatus.rolledBack,
      persistedAtomically: false,
      routeVersionId: proposal.routeVersionId,
    );
  }

  @override
  Future<void> recordProgressEvent({
    required String questId,
    required String missionId,
    required String eventType,
    required String eventKey,
    Map<String, Object?> metadata = const {},
  }) async {}
}

class SupabaseRouteReplanningRepository implements RouteReplanningRepository {
  const SupabaseRouteReplanningRepository(this.client);

  final SupabaseClient client;

  @override
  Future<void> saveProposal(RouteChangeProposal proposal) async {
    await client.from('route_versions').insert({
      'id': proposal.routeVersionId,
      'quest_id': proposal.questId,
      'status': 'proposed',
      'generated_by': 'arc',
      'generation_reason': proposal.reason.name,
      'version_number': await _nextVersion(proposal.questId),
      'route_snapshot': proposal.routeSnapshot,
    });
    await client.from('route_change_proposals').insert({
      'id': proposal.id,
      'quest_id': proposal.questId,
      'route_version_id': proposal.routeVersionId,
      'proposal_type': proposal.reason.name,
      'summary': proposal.summary,
      'reason': proposal.reason.name,
      'confidence_score': proposal.confidence,
      'status': proposal.status.name,
      'base_snapshot': proposal.routeSnapshot,
    });
    await client.from('route_change_items').insert([
      for (final item in proposal.items)
        {
          'id': item.id,
          'proposal_id': proposal.id,
          'action_type': item.action.name,
          'target_mission_id': item.targetMissionId,
          'target_task_id': item.targetTaskId,
          'title': item.title,
          'before_data': item.beforeData,
          'after_data': item.afterData,
          'reason': item.reason,
          'safety_level': item.safetyLevel,
        },
    ]);
  }

  Future<int> _nextVersion(String questId) async {
    final rows = await client
        .from('route_versions')
        .select('version_number')
        .eq('quest_id', questId)
        .order('version_number', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 1;
    return ((rows.first['version_number'] as int?) ?? 0) + 1;
  }

  @override
  Future<void> resolveProposal(
    String proposalId,
    RouteProposalStatus status, {
    List<String> acceptedItemIds = const [],
  }) async {
    await client
        .from('route_change_proposals')
        .update({
          'status': status.name,
          'accepted_item_ids': acceptedItemIds,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', proposalId);
  }

  @override
  Future<RouteMutationResult> applyProposal({
    required RouteChangeProposal proposal,
    required List<String> acceptedItemIds,
  }) async {
    final selected = proposal.items
        .where((item) => acceptedItemIds.contains(item.id))
        .toList(growable: false);
    if (selected.length == 1 &&
        selected.single.action == RouteChangeAction.replace) {
      final value = await client.rpc(
        'apply_mission_regeneration_proposal',
        params: {
          'p_proposal_id': proposal.id,
          'p_item_id': selected.single.id,
          'p_expected_route_version_id': proposal.routeVersionId,
        },
      );
      return _mutationFromValue(value, persistedAtomically: true);
    }
    final value = await client.rpc(
      selected.any(
            (item) =>
                item.targetTaskId != null ||
                (item.action == RouteChangeAction.add &&
                    item.afterData['task'] is Map),
          )
          ? 'apply_task_aware_route_change_proposal'
          : 'apply_route_change_proposal',
      params: {
        'p_proposal_id': proposal.id,
        'p_accepted_item_ids': acceptedItemIds,
        'p_expected_route_version_id': proposal.routeVersionId,
      },
    );
    return _mutationFromValue(value, persistedAtomically: true);
  }

  @override
  Future<RouteMutationResult> rollbackProposal(String proposalId) async {
    final taskItems = await client
        .from('route_change_items')
        .select('target_task_id,action_type,after_data')
        .eq('proposal_id', proposalId)
        .limit(20);
    final taskAware = taskItems.any(
      (value) =>
          value['target_task_id'] != null ||
          (value['action_type'] == 'add' &&
              value['after_data'] is Map &&
              (value['after_data'] as Map).containsKey('task')),
    );
    final value = await client.rpc(
      taskAware
          ? 'rollback_task_aware_route_change_proposal'
          : 'rollback_route_change_proposal_v2',
      params: {'p_proposal_id': proposalId},
    );
    return _mutationFromValue(value, persistedAtomically: true);
  }

  @override
  Future<void> recordProgressEvent({
    required String questId,
    required String missionId,
    required String eventType,
    required String eventKey,
    Map<String, Object?> metadata = const {},
  }) async {
    await client.from('mission_progress_events').upsert({
      'quest_id': questId,
      'mission_id': missionId,
      'event_type': eventType,
      'event_key': eventKey,
      'metadata': metadata,
    }, onConflict: 'quest_id,event_key');
  }

  @override
  Future<List<RouteChangeProposal>> findByQuest(String questId) async {
    final rows = await client
        .from('route_change_proposals')
        .select('*, route_change_items(*)')
        .eq('quest_id', questId)
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map((row) => _fromRow(Map<String, dynamic>.from(row))).toList();
  }

  RouteChangeProposal _fromRow(Map<String, dynamic> row) {
    final itemRows = (row['route_change_items'] as List? ?? const []);
    return RouteChangeProposal(
      id: row['id'] as String,
      routeVersionId: row['route_version_id'] as String,
      questId: row['quest_id'] as String,
      reason: RouteProposalReason.values.byName(row['reason'] as String),
      summary: row['summary'] as String,
      confidence: (row['confidence_score'] as num).toDouble(),
      status: RouteProposalStatus.values.byName(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      routeSnapshot: Map<String, Object?>.from(
        row['base_snapshot'] as Map? ?? const {},
      ),
      staleReason: row['stale_reason'] as String?,
      conflictSnapshot: Map<String, Object?>.from(
        row['conflict_snapshot'] as Map? ?? const {},
      ),
      items: [
        for (final value in itemRows)
          () {
            final item = Map<String, dynamic>.from(value as Map);
            return RouteChangeItem(
              id: item['id'] as String,
              action: RouteChangeAction.values.byName(
                item['action_type'] as String,
              ),
              targetMissionId: item['target_mission_id'] as String?,
              targetTaskId: item['target_task_id'] as String?,
              title: item['title'] as String,
              reason: item['reason'] as String,
              beforeData: Map<String, Object?>.from(
                item['before_data'] as Map? ?? const {},
              ),
              afterData: Map<String, Object?>.from(
                item['after_data'] as Map? ?? const {},
              ),
              safetyLevel: item['safety_level'] as int? ?? 2,
            );
          }(),
      ],
    );
  }

  RouteMutationResult _mutationFromValue(
    Object? value, {
    required bool persistedAtomically,
  }) {
    if (value is! Map) {
      throw const FormatException('航路更新結果を確認できませんでした。');
    }
    final row = Map<String, dynamic>.from(value);
    return RouteMutationResult(
      proposalId: row['proposal_id'] as String,
      questId: row['quest_id'] as String,
      routeVersionId: row['route_version_id'] as String?,
      status: RouteProposalStatus.values.byName(row['status'] as String),
      persistedAtomically: persistedAtomically,
      staleReason: row['stale_reason'] as String?,
      conflictSnapshot: Map<String, Object?>.from(
        row['conflict_snapshot'] as Map? ?? const {},
      ),
    );
  }
}
