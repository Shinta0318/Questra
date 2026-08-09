import 'package:uuid/uuid.dart';

const _routeUuid = Uuid();

enum RouteChangeAction {
  add,
  remove,
  replace,
  reorder,
  split,
  merge,
  reschedule,
  reestimate,
  pause,
  resume,
}

enum RouteProposalStatus {
  pending,
  accepted,
  partiallyAccepted,
  rejected,
  expired,
  rolledBack,
  stale,
}

enum RouteProposalReason {
  aheadOfSchedule,
  deadlineRisk,
  stalled,
  contextChanged,
  manualReview,
}

class RouteMutationResult {
  const RouteMutationResult({
    required this.proposalId,
    required this.questId,
    required this.status,
    required this.persistedAtomically,
    this.routeVersionId,
    this.staleReason,
    this.conflictSnapshot = const {},
  });

  final String proposalId;
  final String questId;
  final RouteProposalStatus status;
  final bool persistedAtomically;
  final String? routeVersionId;
  final String? staleReason;
  final Map<String, Object?> conflictSnapshot;
}

class RouteChangeItem {
  RouteChangeItem({
    String? id,
    required this.action,
    required this.title,
    required this.reason,
    required this.beforeData,
    required this.afterData,
    this.targetMissionId,
    this.targetTaskId,
    this.safetyLevel = 2,
  }) : id = id ?? _routeUuid.v4();

  final String id;
  final RouteChangeAction action;
  final String title;
  final String reason;
  final Map<String, Object?> beforeData;
  final Map<String, Object?> afterData;
  final String? targetMissionId;
  final String? targetTaskId;
  final int safetyLevel;
}

class RouteChangeProposal {
  RouteChangeProposal({
    String? id,
    String? routeVersionId,
    required this.questId,
    required this.reason,
    required this.summary,
    required this.confidence,
    required this.items,
    this.routeSnapshot = const {},
    this.status = RouteProposalStatus.pending,
    this.staleReason,
    this.conflictSnapshot = const {},
    DateTime? createdAt,
  }) : id = id ?? _routeUuid.v4(),
       routeVersionId = routeVersionId ?? _routeUuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String routeVersionId;
  final String questId;
  final RouteProposalReason reason;
  final String summary;
  final double confidence;
  final List<RouteChangeItem> items;
  final Map<String, Object?> routeSnapshot;
  final RouteProposalStatus status;
  final String? staleReason;
  final Map<String, Object?> conflictSnapshot;
  final DateTime createdAt;

  RouteChangeProposal copyWith({
    RouteProposalStatus? status,
    String? staleReason,
    Map<String, Object?>? conflictSnapshot,
  }) {
    return RouteChangeProposal(
      id: id,
      routeVersionId: routeVersionId,
      questId: questId,
      reason: reason,
      summary: summary,
      confidence: confidence,
      items: items,
      routeSnapshot: routeSnapshot,
      status: status ?? this.status,
      staleReason: staleReason ?? this.staleReason,
      conflictSnapshot: conflictSnapshot ?? this.conflictSnapshot,
      createdAt: createdAt,
    );
  }
}

class RouteProposalValidator {
  const RouteProposalValidator();

  RouteChangeProposal validate(RouteChangeProposal proposal) {
    if (proposal.questId.trim().isEmpty || proposal.items.isEmpty) {
      throw const FormatException('航路変更案に必要な情報がありません。');
    }
    if (!proposal.confidence.isFinite ||
        proposal.confidence < 0 ||
        proposal.confidence > 1) {
      throw const FormatException('航路変更案の信頼度が不正です。');
    }
    if (proposal.items.length > 20) {
      throw const FormatException('一度に確認できる変更は20件までです。');
    }
    for (final item in proposal.items) {
      if (item.title.trim().isEmpty ||
          item.reason.trim().isEmpty ||
          item.safetyLevel < 1 ||
          item.safetyLevel > 3) {
        throw const FormatException('航路変更の差分が不正です。');
      }
      final destructive = {
        RouteChangeAction.remove,
        RouteChangeAction.replace,
        RouteChangeAction.merge,
      }.contains(item.action);
      if (destructive && item.safetyLevel != 3) {
        throw const FormatException('破壊的な変更には明示承認が必要です。');
      }
    }
    return proposal;
  }
}
