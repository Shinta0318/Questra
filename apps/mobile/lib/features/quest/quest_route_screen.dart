import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import 'quest_controller.dart';
import 'quest_model.dart';
import 'route_replanning_controller.dart';
import 'route_replanning_model.dart';
import 'route_replanning_presentation.dart';
import 'route_mutation_journal.dart';

class QuestRouteScreen extends ConsumerStatefulWidget {
  const QuestRouteScreen({required this.questId, super.key});

  final String questId;

  @override
  ConsumerState<QuestRouteScreen> createState() => _QuestRouteScreenState();
}

class _QuestRouteScreenState extends ConsumerState<QuestRouteScreen> {
  bool _isReviewing = false;
  bool _isApplying = false;
  bool _isDialogOpen = false;
  bool _isUndoing = false;
  String? _undoProposalId;
  String? _recoveryProposalId;
  final Set<String> _unavailableUndoIds = {};
  String? _error;
  String? _notice;
  Future<RouteJournalInspection?>? _journalFuture;
  String? _journalScope;

  @override
  void didUpdateWidget(covariant QuestRouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questId != widget.questId) {
      _journalFuture = null;
      _journalScope = null;
    }
  }

  Future<RouteJournalInspection?> _inspectJournal(
    Quest quest,
    List<Mission> missions,
  ) {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final scope = '$ownerId:${quest.id}';
    if (_journalFuture == null || _journalScope != scope) {
      _journalScope = scope;
      _journalFuture = ref
          .read(routeReplanningControllerProvider.notifier)
          .inspectRouteJournal(quest, missions);
    }
    return _journalFuture!;
  }

  void _refreshJournal() {
    if (!mounted) return;
    setState(() => _journalFuture = null);
  }

  @override
  Widget build(BuildContext context) {
    final quest = ref
        .watch(questControllerProvider)
        .where((item) => item.id == widget.questId)
        .firstOrNull;
    final missions =
        ref
            .watch(missionControllerProvider)
            .where(
              (mission) =>
                  mission.questId == widget.questId &&
                  mission.routeState != MissionRouteState.removed,
            )
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final pendingProposal = ref.watch(
      routeReplanningControllerProvider.select(
        (proposals) => proposals[widget.questId],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Questの航路')),
      body: FutureBuilder<RouteJournalInspection?>(
        future: quest == null ? null : _inspectJournal(quest, missions),
        builder: (context, journalState) {
          final journalReady =
              journalState.connectionState == ConnectionState.done &&
              !journalState.hasError;
          final journal = journalReady ? journalState.data : null;
          final controller = ref.read(
            routeReplanningControllerProvider.notifier,
          );
          final undoProposalId =
              _undoProposalId ??
              controller.undoProposalIdForQuest(widget.questId);
          final recoveryProposalId =
              _recoveryProposalId ??
              (journal?.stage == RouteJournalStage.recoveryNeeded &&
                      controller.hasFailedAcceptanceRecovery(
                        journal!.proposalId,
                      )
                  ? journal.proposalId
                  : null);
          final canReview =
              quest != null &&
              missions.isNotEmpty &&
              !_isReviewing &&
              !_isUndoing &&
              journalReady &&
              journal == null;
          return QuestraResponsiveListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                quest?.title ?? 'Questが見つかりません',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text('Missionの順序とつながりを確認できます。変更は承認するまで反映されません。'),
              const SizedBox(height: 18),
              if (quest != null && !journalReady && !journalState.hasError)
                Semantics(
                  liveRegion: true,
                  child: const _RouteMessage(
                    icon: Icons.hourglass_top,
                    message: '前回の航路操作を確認しています。',
                  ),
                ),
              if (journalState.hasError)
                Semantics(
                  liveRegion: true,
                  child: const _RouteMessage(
                    icon: Icons.warning_amber_rounded,
                    message: '航路の復旧記録を確認できません。新しい変更は停止しています。現在の航路を確認してください。',
                    isError: true,
                  ),
                ),
              if (journal != null) ...[
                Semantics(
                  liveRegion: true,
                  child: _RouteMessage(
                    icon: Icons.warning_amber_rounded,
                    message: _journalMessage(journal),
                    isError: true,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.questDetail(widget.questId)),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('現在のQuestを確認'),
                ),
                if (journal.canAcknowledge)
                  OutlinedButton.icon(
                    onPressed: _isReviewing || _isUndoing
                        ? null
                        : () => _acknowledgeJournal(journal),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('照合結果を確認して続ける'),
                  ),
              ],
              if (missions.isEmpty)
                const QuestraCard(
                  padding: EdgeInsets.all(16),
                  child: Text('航路を見直すには、先にMissionを1件以上作成してください。'),
                )
              else
                for (var index = 0; index < missions.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: QuestraCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(missions[index].title),
                        subtitle: Text(
                          '${missions[index].required ? '必須' : '任意'}'
                          '${missions[index].dependencyIds.isEmpty ? '' : ' / 前提 ${missions[index].dependencyIds.length}件'}',
                        ),
                        trailing: Icon(
                          missions[index].status == MissionStatus.completed
                              ? Icons.verified
                              : Icons.chevron_right,
                        ),
                        onTap: () => context.push(
                          AppRoutes.missionDetail(
                            widget.questId,
                            missions[index].id,
                          ),
                        ),
                      ),
                    ),
                  ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: _RouteMessage(
                    icon: Icons.error_outline,
                    message: _error!,
                    isError: true,
                  ),
                ),
              ] else if (_notice != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: _RouteMessage(
                    icon: Icons.info_outline,
                    message: _notice!,
                  ),
                ),
              ],
              if (undoProposalId != null &&
                  !_unavailableUndoIds.contains(undoProposalId)) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isReviewing || _isUndoing ? null : _undoRoute,
                  icon: _isUndoing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.undo),
                  label: Text(_isUndoing ? '航路を元に戻しています' : '航路を元に戻す'),
                ),
              ],
              if (recoveryProposalId != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isReviewing || _isUndoing ? null : _retryRecovery,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('航路の復旧を再確認'),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: canReview
                    ? () => _reviewRoute(quest, missions, pendingProposal)
                    : null,
                icon: _isReviewing && !_isDialogOpen
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_outlined),
                label: Text(
                  _isReviewing
                      ? _isDialogOpen
                            ? '提案を確認中'
                            : _isApplying
                            ? '航路を保存しています'
                            : '航路を確認しています'
                      : pendingProposal?.status == RouteProposalStatus.stale
                      ? '最新の進捗で提案を作り直す'
                      : pendingProposal == null
                      ? 'Arcと航路を見直す'
                      : 'Arcからの提案を確認',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _journalMessage(RouteJournalInspection journal) {
    if (journal.canAcknowledge) {
      return switch (journal.stage) {
        RouteJournalStage.applying =>
          '前回の航路変更は完了していません。現在の航路は変更前と一致します。確認するまで新しい変更は停止します。',
        RouteJournalStage.applied => '前回の航路変更は保存後の内容と一致します。確認するまで新しい変更は停止します。',
        RouteJournalStage.recoveryNeeded =>
          '前回の復旧は未完了として記録されていますが、現在の航路は変更前と一致します。内容を確認してから続けられます。',
        RouteJournalStage.recovering =>
          '前回の元に戻す操作は、復元先の航路と一致します。内容を確認してから続けられます。',
      };
    }
    return journal.stage == RouteJournalStage.recoveryNeeded
        ? '前回の航路復旧が完了していません。新しい変更は停止しています。現在のQuestを確認してください。'
        : '前回の航路操作と現在の内容が一致しません。後続の変更を守るため、新しい変更は停止しています。';
  }

  Future<void> _acknowledgeJournal(RouteJournalInspection journal) async {
    if (_isReviewing || _isUndoing || !journal.canAcknowledge) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('現在の航路を確認しましたか？'),
        content: Text(
          journal.matchesBefore
              ? '現在の航路は記録された変更前の内容と一致しています。QuestとMissionを確認し、この状態で続ける場合のみ操作記録を整理します。航路そのものは変更しません。'
              : '現在の航路は記録された保存後または復元先の内容と一致しています。QuestとMissionを確認し、この状態で続ける場合のみ操作記録を整理します。航路そのものは変更しません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('確認して続ける'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isUndoing = true);
    try {
      final cleared = await ref
          .read(routeReplanningControllerProvider.notifier)
          .acknowledgeRouteJournal(widget.questId, journal.proposalId);
      if (!mounted) return;
      setState(() {
        _error = cleared ? null : '航路の状態が変わりました。現在の内容をもう一度確認してください。';
        _notice = cleared ? '現在の航路を確認しました。' : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = '復旧記録を確認できません。現在の航路を確認してください。');
      }
    } finally {
      if (mounted) {
        setState(() => _isUndoing = false);
        _refreshJournal();
      }
    }
  }

  Future<void> _reviewRoute(
    Quest quest,
    List<Mission> missions,
    RouteChangeProposal? existing,
  ) async {
    if (_isReviewing) return;
    setState(() {
      _isReviewing = true;
      _error = null;
      _notice = null;
    });
    try {
      final proposal = existing?.status == RouteProposalStatus.stale
          ? await ref
                .read(routeReplanningControllerProvider.notifier)
                .refreshStale(quest, missions, existing!)
          : existing ??
                await ref
                    .read(routeReplanningControllerProvider.notifier)
                    .review(quest, missions);
      if (!mounted) return;
      if (proposal == null) {
        setState(() => _notice = '今は航路を変更する必要はなさそうです。');
        return;
      }
      setState(() => _isDialogOpen = true);
      final selection = await _showRouteReview(context, proposal);
      if (!mounted || selection == null) return;
      setState(() => _isDialogOpen = false);
      switch (selection.decision) {
        case _RouteReviewDecision.later:
          setState(() => _notice = '提案を保存しました。いつでもここから確認できます。');
          return;
        case _RouteReviewDecision.reject:
          await ref
              .read(routeReplanningControllerProvider.notifier)
              .reject(proposal);
          if (mounted) setState(() => _notice = '今回は航路を変更しません。');
          return;
        case _RouteReviewDecision.accept:
          setState(() => _isApplying = true);
          final result = await ref
              .read(routeReplanningControllerProvider.notifier)
              .accept(quest, missions, proposal, selection.itemIds);
          if (!mounted) return;
          if (result?.status == RouteProposalStatus.stale) {
            setState(() {
              _error = result?.staleReason ?? '提案後に進捗が変わりました。提案を作り直してください。';
              _recoveryProposalId = result?.recoveryIncomplete == true
                  ? proposal.id
                  : null;
            });
            return;
          }
          if (result == null) {
            setState(() => _error = '反映する変更を選んでください。');
            return;
          }
          if (result.recoveryIncomplete) {
            setState(() {
              _undoProposalId = proposal.id;
              _error = result.staleReason ?? '航路は更新されました。復旧記録を確認してください。';
            });
            _refreshJournal();
            return;
          }
          setState(() {
            _undoProposalId = proposal.id;
            _notice = '承認した内容で航路を更新しました。元に戻すこともできます。';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('承認した内容で航路を更新しました。'),
              action: SnackBarAction(label: '元に戻す', onPressed: _undoRoute),
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '航路の確認または保存を完了できませんでした。現在の内容を確認してください。');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReviewing = false;
          _isApplying = false;
          _isDialogOpen = false;
        });
      }
    }
  }

  Future<void> _undoRoute() async {
    final proposalId =
        _undoProposalId ??
        ref
            .read(routeReplanningControllerProvider.notifier)
            .undoProposalIdForQuest(widget.questId);
    if (proposalId == null || _isUndoing || _isReviewing) return;
    setState(() {
      _isUndoing = true;
      _error = null;
    });
    final result = await ref
        .read(routeReplanningControllerProvider.notifier)
        .undo(proposalId);
    if (!mounted) return;
    setState(() {
      _isUndoing = false;
      if (result.restored) {
        _undoProposalId = null;
        _notice = result.message;
        _journalFuture = null;
      } else {
        _error = result.message;
        if (result.status == RouteUndoStatus.stale ||
            result.status == RouteUndoStatus.unavailable) {
          _undoProposalId = null;
          _unavailableUndoIds.add(proposalId);
        }
      }
    });
  }

  Future<void> _retryRecovery() async {
    var proposalId = _recoveryProposalId;
    if (proposalId == null) {
      final quest = ref
          .read(questControllerProvider)
          .where((item) => item.id == widget.questId)
          .firstOrNull;
      if (quest != null) {
        final journal = await ref
            .read(routeReplanningControllerProvider.notifier)
            .inspectRouteJournal(quest, ref.read(missionControllerProvider));
        if (journal?.stage == RouteJournalStage.recoveryNeeded &&
            ref
                .read(routeReplanningControllerProvider.notifier)
                .hasFailedAcceptanceRecovery(journal!.proposalId)) {
          proposalId = journal.proposalId;
        }
      }
    }
    if (proposalId == null || _isReviewing || _isUndoing) return;
    setState(() => _isUndoing = true);
    final result = await ref
        .read(routeReplanningControllerProvider.notifier)
        .retryFailedAcceptanceRecovery(proposalId);
    if (!mounted) return;
    setState(() {
      _isUndoing = false;
      if (result.restored) {
        _recoveryProposalId = null;
        _error = null;
        _notice = result.message;
        _journalFuture = null;
      } else {
        _error = result.message;
        if (result.status == RouteUndoStatus.unavailable ||
            result.status == RouteUndoStatus.stale) {
          _recoveryProposalId = null;
        }
      }
    });
  }
}

Future<_RouteReviewSelection?> _showRouteReview(
  BuildContext context,
  RouteChangeProposal proposal,
) {
  final selected = proposal.items.map((item) => item.id).toSet();
  return showDialog<_RouteReviewSelection>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Arcから航路更新の提案'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proposal.summary),
                Text(routeProposalSourceLabel(proposal)),
                const SizedBox(height: 8),
                Text('提案の確度 ${(proposal.confidence * 100).round()}%'),
                const Divider(height: 24),
                for (final item in proposal.items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(item.id),
                    onChanged: (value) => setDialogState(() {
                      if (value ?? false) {
                        selected.add(item.id);
                      } else {
                        selected.remove(item.id);
                      }
                    }),
                    title: Text(item.title),
                    subtitle: Text(
                      '${routeChangeTargetLabel(item)} ・ '
                      '${routeChangeActionLabel(item.action)}\n'
                      '${item.reason}\n${routeChangeDiffLabel(item)}',
                    ),
                    isThreeLine: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                const Text(
                  '承認するまでQuest、Mission、Task、期限は変わりません。削除を含む変更は必ず明示確認します。',
                  style: TextStyle(fontSize: 12, color: QuestraColors.slate),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(const _RouteReviewSelection(_RouteReviewDecision.reject, {})),
            child: const Text('今回は変更しない'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(const _RouteReviewSelection(_RouteReviewDecision.later, {})),
            child: const Text('あとで確認'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.of(dialogContext).pop(
                    _RouteReviewSelection(
                      _RouteReviewDecision.accept,
                      Set<String>.of(selected),
                    ),
                  ),
            child: const Text('選んだ変更を反映'),
          ),
        ],
      ),
    ),
  );
}

enum _RouteReviewDecision { accept, reject, later }

class _RouteReviewSelection {
  const _RouteReviewSelection(this.decision, this.itemIds);

  final _RouteReviewDecision decision;
  final Set<String> itemIds;
}

class _RouteMessage extends StatelessWidget {
  const _RouteMessage({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => QuestraCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Icon(icon, color: isError ? Theme.of(context).colorScheme.error : null),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
