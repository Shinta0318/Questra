import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import 'guild_discovery_detail_screen.dart';
import 'guild_discovery_model.dart';
import 'guild_discovery_providers.dart';

class GuildDiscoveryScreen extends ConsumerStatefulWidget {
  const GuildDiscoveryScreen({super.key});

  @override
  ConsumerState<GuildDiscoveryScreen> createState() =>
      _GuildDiscoveryScreenState();
}

class _GuildDiscoveryScreenState extends ConsumerState<GuildDiscoveryScreen> {
  GuildDiscoverySection _section = GuildDiscoverySection.recommended;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(guildDiscoveryFeedProvider);
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(title: const Text('Guild')),
      body: QuestraScreenSurface(
        child: feed.when(
          loading: () => const _DiscoveryLoading(),
          error: (error, stackTrace) => _DiscoveryError(
            onRetry: () => ref.invalidate(guildDiscoveryFeedProvider),
          ),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(List<GuildDiscoveryQuest> candidates) {
    final results = ref
        .watch(guildDiscoveryRankingServiceProvider)
        .rank(candidates: candidates, section: _section, limit: 20);

    return QuestraResponsiveListView(
      showScrollbar: true,
      onRefresh: () async {
        ref.invalidate(guildDiscoveryFeedProvider);
        await ref.read(guildDiscoveryFeedProvider.future);
      },
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const _DiscoveryHeader(),
        const SizedBox(height: 18),
        _DiscoverySectionPicker(
          selected: _section,
          onSelected: (section) => setState(() => _section = section),
        ),
        const SizedBox(height: 22),
        if (results.isEmpty)
          ArcEmptyState(
            title: _emptyTitle,
            message: _emptyMessage,
            actionLabel: 'ArcとQuestを考える',
            icon: Icons.explore_outlined,
            onAction: () => context.go(AppRoutes.arc),
          )
        else
          ...results.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DiscoveryQuestCard(
                result: result,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GuildDiscoveryDetailScreen(
                      quest: result.quest,
                      recommendationReason: result.reason,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String get _emptyTitle => switch (_section) {
    GuildDiscoverySection.recommended => 'おすすめを準備しています',
    GuildDiscoverySection.trending => '注目のQuestはまだありません',
    GuildDiscoverySection.recent => '公開されたQuestはまだありません',
    GuildDiscoverySection.seekingCompanions => '仲間を募集中のQuestはありません',
    GuildDiscoverySection.missionLibrary => '公開Missionはまだありません',
  };

  String get _emptyMessage => switch (_section) {
    GuildDiscoverySection.recommended =>
      'Questが育つと、関心に近い公開航路をここで見つけられるようになります。',
    GuildDiscoverySection.trending => '役立つ航路が集まり次第、達成状況と新しさを見て紹介します。',
    GuildDiscoverySection.recent => '公開審査を通った新しい航路だけを、ここへ届けます。',
    GuildDiscoverySection.seekingCompanions => '参加は任意です。まずは自分のQuestから始められます。',
    GuildDiscoverySection.missionLibrary => '必要な一歩だけ取り入れられるMissionを準備しています。',
  };
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '次の挑戦を見つける',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '誰かの航路から、今の自分に合う一歩を探せます。',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.parchment),
          ),
        ],
      ),
    );
  }
}

class _DiscoverySectionPicker extends StatelessWidget {
  const _DiscoverySectionPicker({
    required this.selected,
    required this.onSelected,
  });

  final GuildDiscoverySection selected;
  final ValueChanged<GuildDiscoverySection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<GuildDiscoverySection>(
        showSelectedIcon: false,
        segments: GuildDiscoverySection.values
            .map(
              (section) => ButtonSegment<GuildDiscoverySection>(
                value: section,
                icon: Icon(_sectionIcon(section), size: 18),
                label: Text(_sectionLabel(section)),
              ),
            )
            .toList(growable: false),
        selected: {selected},
        onSelectionChanged: (selection) => onSelected(selection.first),
      ),
    );
  }

  String _sectionLabel(GuildDiscoverySection section) => switch (section) {
    GuildDiscoverySection.recommended => 'おすすめ',
    GuildDiscoverySection.trending => '注目',
    GuildDiscoverySection.recent => '新着',
    GuildDiscoverySection.seekingCompanions => '仲間',
    GuildDiscoverySection.missionLibrary => 'Mission',
  };

  IconData _sectionIcon(GuildDiscoverySection section) => switch (section) {
    GuildDiscoverySection.recommended => Icons.auto_awesome_outlined,
    GuildDiscoverySection.trending => Icons.trending_up_rounded,
    GuildDiscoverySection.recent => Icons.schedule_rounded,
    GuildDiscoverySection.seekingCompanions => Icons.group_outlined,
    GuildDiscoverySection.missionLibrary => Icons.route_outlined,
  };
}

class _DiscoveryQuestCard extends StatelessWidget {
  const _DiscoveryQuestCard({required this.result, required this.onTap});

  final GuildDiscoveryResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quest = result.quest;
    return Material(
      color: AppColors.midnightNavy.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      quest.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quest.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.parchment),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Metric(
                    icon: Icons.speed_rounded,
                    label: '難易度 ${quest.difficultyScore}/5',
                  ),
                  if (quest.estimatedDurationDays != null)
                    _Metric(
                      icon: Icons.calendar_month_outlined,
                      label: _durationLabel(quest.estimatedDurationDays!),
                    ),
                  if (quest.copyCount > 0)
                    _Metric(
                      icon: Icons.call_split_rounded,
                      label: '${quest.copyCount}件の航路へ派生',
                    ),
                ],
              ),
              if (quest.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  quest.tags.take(4).join('  ·  '),
                  style: const TextStyle(color: AppColors.skyBlue),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      result.reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.parchment,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _durationLabel(int days) {
    if (days < 14) return '約$days日';
    if (days < 60) return '約${(days / 7).ceil()}週間';
    return '約${(days / 30).ceil()}か月';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.auroraTeal),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.white)),
      ],
    );
  }
}

class _DiscoveryLoading extends StatelessWidget {
  const _DiscoveryLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: '公開Questを読み込んでいます',
        child: const CircularProgressIndicator(color: AppColors.gold),
      ),
    );
  }
}

class _DiscoveryError extends StatelessWidget {
  const _DiscoveryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.gold,
              size: 40,
            ),
            const SizedBox(height: 14),
            const Text(
              '航路を読み込めませんでした',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            IconButton.filledTonal(
              tooltip: 'もう一度読み込む',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
