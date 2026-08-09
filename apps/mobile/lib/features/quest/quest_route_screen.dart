import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import 'quest_controller.dart';
import 'quest_model.dart';
import 'route_replanning_controller.dart';
import 'route_replanning_model.dart';
import 'route_replanning_presentation.dart';

class QuestRouteScreen extends ConsumerStatefulWidget {
  const QuestRouteScreen({required this.questId, super.key});

  final String questId;

  @override
  ConsumerState<QuestRouteScreen> createState() => _QuestRouteScreenState();
}

class _QuestRouteScreenState extends ConsumerState<QuestRouteScreen> {
  bool _isReviewing = false;
  String? _error;
  String? _notice;

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
    final canReview = quest != null && missions.isNotEmpty && !_isReviewing;

    return Scaffold(
      appBar: AppBar(title: const Text('Questの航路')),
      body: QuestraResponsiveListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            quest?.title ?? 'Questが見つかりません',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text('Missionの順序とつながりを確認できます。変更は承認するまで反映されません。'),
          const SizedBox(height: 18),
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
            _RouteMessage(
              icon: Icons.error_outline,
              message: _error!,
              isError: true,
            ),
          ] else if (_notice != null) ...[
            const SizedBox(height: 12),
            _RouteMessage(icon: Icons.auto_awesome_outlined, message: _notice!),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: canReview
                ? () => _reviewRoute(quest, missions, pendingProposal)
                : null,
            icon: _isReviewing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined),
            label: Text(
              _isReviewing
                  ? '航路を確認しています'
                  : pendingProposal?.status == RouteProposalStatus.stale
                  ? '最新の進捗で提案を作り直す'
                  : pendingProposal == null
                  ? 'Arcと航路を見直す'
                  : 'Arcからの提案を確認',
            ),
          ),
        ],
      ),
    );
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
      setState(() => _isReviewing = false);
      final selection = await _showRouteReview(context, proposal);
      if (!mounted || selection == null) return;
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
          final result = await ref
              .read(routeReplanningControllerProvider.notifier)
              .accept(quest, missions, proposal, selection.itemIds);
          if (!mounted) return;
          if (result?.status == RouteProposalStatus.stale) {
            setState(() {
              _error = result?.staleReason ?? '提案後に進捗が変わりました。提案を作り直してください。';
            });
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('承認した内容で航路を更新しました。'),
              action: SnackBarAction(
                label: '元に戻す',
                onPressed: () => unawaited(
                  ref
                      .read(routeReplanningControllerProvider.notifier)
                      .undo(proposal.id),
                ),
              ),
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '航路を確認できませんでした。内容は変更されていません。');
      }
    } finally {
      if (mounted) setState(() => _isReviewing = false);
    }
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
