import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import '../../widgets/navigation/questra_route_back_button.dart';
import '../auth/auth_controller.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
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
  final TextEditingController _searchController = TextEditingController();
  GuildDiscoverySection _section = GuildDiscoverySection.recommended;
  String _query = '';
  String? _contextQuestId;
  String? _copyingPublicationId;
  bool _publishing = false;
  bool _copyDialogOpen = false;
  final Map<String, String> _copyRequestKeys = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pilotStatus = ref.watch(guildPilotStatusProvider);
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        leading: const QuestraRouteBackButton(
          fallbackRoute: AppRoutes.home,
          fallbackTooltip: 'ホームへ戻る',
        ),
        title: const Text('Guild'),
      ),
      body: QuestraScreenSurface(
        child: pilotStatus.when(
          loading: () => const _DiscoveryLoading(),
          error: (error, stackTrace) => _DiscoveryError(
            onRetry: () => ref.invalidate(guildPilotStatusProvider),
          ),
          data: (status) => status.enabled
              ? _buildPilotContent(status)
              : _PilotGate(status: status),
        ),
      ),
    );
  }

  Widget _buildPilotContent(GuildPilotStatus status) {
    final feed = ref.watch(guildDiscoveryFeedProvider);
    return feed.when(
      loading: () => const _DiscoveryLoading(),
      error: (error, stackTrace) => _DiscoveryError(
        onRetry: () => ref.invalidate(guildDiscoveryFeedProvider),
      ),
      data: (candidates) => _buildContent(candidates, status),
    );
  }

  Widget _buildContent(
    List<GuildDiscoveryQuest> candidates,
    GuildPilotStatus status,
  ) {
    final discoveryRepository = ref.watch(guildDiscoveryRepositoryProvider);
    final ownQuests = ref
        .watch(questControllerProvider)
        .where((quest) => quest.status == QuestStatus.active)
        .toList(growable: false);
    final selectedQuest = ownQuests.where(
      (quest) => quest.id == _contextQuestId,
    );
    final contextQuest = selectedQuest.isEmpty ? null : selectedQuest.first;
    final profile = contextQuest == null
        ? const GuildDiscoveryProfile()
        : GuildDiscoveryProfile(
            preferredTags: {
              contextQuest.category,
              contextQuest.dna?.valueFor('category') ?? '',
              contextQuest.dna?.valueFor('theme') ?? '',
            }.where((tag) => tag.isNotEmpty && tag != '未評価').toList(),
          );
    final results = ref
        .watch(guildDiscoveryRankingServiceProvider)
        .rank(
          candidates: candidates,
          profile: profile,
          section: _section,
          query: _query,
          limit: 20,
        );

    return QuestraResponsiveListView(
      showScrollbar: true,
      onRefresh: () async {
        ref.invalidate(guildDiscoveryFeedProvider);
        await ref.read(guildDiscoveryFeedProvider.future);
      },
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        _DiscoveryHeader(cohort: status.cohort),
        if (!status.configured) ...[
          const SizedBox(height: 12),
          Text(
            'オフラインプレビュー：公開Questの閲覧・取り込みは実接続版で利用できます。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.parchment),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          key: const Key('guild-search'),
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(color: AppColors.deepNavy),
          decoration: const InputDecoration(
            labelText: '公開Questを探す',
            hintText: 'タイトル・内容・タグ',
            labelStyle: TextStyle(color: AppColors.deepNavy),
            hintStyle: TextStyle(color: AppColors.deepNavy),
            prefixIconColor: AppColors.deepNavy,
            prefixIcon: Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(),
          ),
        ),
        if (ownQuests.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: const Key('guild-context-quest'),
            initialValue: contextQuest?.id,
            isExpanded: true,
            dropdownColor: AppColors.white,
            style: const TextStyle(color: AppColors.deepNavy),
            decoration: const InputDecoration(
              labelText: '自分のQuestに近い挑戦',
              labelStyle: TextStyle(color: AppColors.deepNavy),
              prefixIconColor: AppColors.deepNavy,
              prefixIcon: Icon(Icons.explore_outlined),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('すべての挑戦'),
              ),
              for (final quest in ownQuests)
                DropdownMenuItem<String?>(
                  value: quest.id,
                  child: Text(quest.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _contextQuestId = value),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '検索とおすすめは、表示中の公開Questから探します。自分のQuestは公開されません。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.parchment),
        ),
        if (ownQuests.isNotEmpty && discoveryRepository != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _publishing ? null : () => _publishQuest(ownQuests),
            icon: const Icon(Icons.publish_outlined),
            label: Text(_publishing ? '公開申請中...' : '自分のQuestを公開申請する'),
          ),
        ],
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
            actionLabel: _query.trim().isEmpty ? 'ArcとQuestを考える' : '検索をクリア',
            icon: Icons.explore_outlined,
            onAction: () {
              if (_query.trim().isNotEmpty) {
                _searchController.clear();
                setState(() => _query = '');
              } else {
                context.go(AppRoutes.arc);
              }
            },
          )
        else
          ...results.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DiscoveryQuestCard(
                result: result,
                onTap: () => _openQuest(
                  result,
                  copyEnabled: discoveryRepository != null,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openQuest(GuildDiscoveryResult result, {required bool copyEnabled}) {
    final repository = ref.read(guildDiscoveryRepositoryProvider);
    if (repository != null) {
      unawaited(
        repository
            .recordDiscoveryOpened(
              publicationId: result.quest.id,
              eventKey: 'guild-open-${const Uuid().v4()}',
            )
            .catchError((_) {}),
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuildDiscoveryDetailScreen(
          quest: result.quest,
          recommendationReason: result.reason,
          onCopy: copyEnabled ? () => _copyQuest(result.quest) : null,
        ),
      ),
    );
  }

  Future<void> _copyQuest(GuildDiscoveryQuest quest) async {
    if (_copyingPublicationId != null || _copyDialogOpen) return;
    _copyDialogOpen = true;
    final GuildQuestCopyOptions? options;
    try {
      options = await _confirmCopy(quest);
    } finally {
      _copyDialogOpen = false;
    }
    if (options == null || !mounted) return;
    final repository = ref.read(guildDiscoveryRepositoryProvider);
    final profile = ref.read(authControllerProvider).profile;
    if (repository == null || profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この機能はログイン済みのPilot参加者向けです。')),
      );
      return;
    }
    _copyingPublicationId = quest.id;
    try {
      final result = await repository.copyToPrivate(
        publicationId: quest.id,
        options: options,
        idempotencyKey: _copyRequestKeys.putIfAbsent(
          quest.id,
          () => 'guild-copy-${const Uuid().v4()}',
        ),
      );
      _copyRequestKeys.remove(quest.id);
      await ref.read(questControllerProvider.notifier).loadForUser(profile.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('${AppRoutes.quest}/${result.questId}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questを取り込めませんでした。内容は変更されていません。')),
      );
    } finally {
      _copyingPublicationId = null;
    }
  }

  Future<GuildQuestCopyOptions?> _confirmCopy(GuildDiscoveryQuest quest) {
    var includeMissions = true;
    return showModalBottomSheet<GuildQuestCopyOptions>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Questを取り込む',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(quest.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('公開済みMissionも取り込む'),
                  subtitle: const Text('審査済みのMissionだけが対象です。'),
                  value: includeMissions,
                  onChanged: (value) =>
                      setSheetState(() => includeMissions = value),
                ),
                const SizedBox(height: 8),
                const Text('自分だけのQuestとして保存します。元のQuestは変更しません。'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(
                    GuildQuestCopyOptions(includeMissions: includeMissions),
                  ),
                  child: const Text('取り込む'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('キャンセル'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publishQuest(List<Quest> ownQuests) async {
    if (_publishing) return;
    final draft = await showModalBottomSheet<({Quest quest, String summary})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PublicationSheet(quests: ownQuests),
    );
    if (draft == null || !mounted) return;
    final repository = ref.read(guildDiscoveryRepositoryProvider);
    if (repository == null) return;
    setState(() => _publishing = true);
    try {
      await repository.publishQuest(
        questId: draft.quest.id,
        summary: draft.summary,
        tags: draft.quest.category.trim().isEmpty
            ? const []
            : [draft.quest.category],
        visibility: GuildDiscoveryVisibility.public,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公開申請を受け付けました。審査が終わるまで一覧には表示されません。')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公開申請ができませんでした。内容を確認して、もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  String get _emptyTitle => _query.trim().isNotEmpty
      ? '一致する公開Questはありません'
      : switch (_section) {
          GuildDiscoverySection.recommended => 'おすすめを準備しています',
          GuildDiscoverySection.trending => '注目のQuestはまだありません',
          GuildDiscoverySection.recent => '公開されたQuestはまだありません',
          GuildDiscoverySection.seekingCompanions => '仲間を募集中のQuestはありません',
        };

  String get _emptyMessage => _query.trim().isNotEmpty
      ? '別の言葉やタグで探してみてください。'
      : switch (_section) {
          GuildDiscoverySection.recommended =>
            'Questが育つと、関心に近い公開航路をここで見つけられるようになります。',
          GuildDiscoverySection.trending => '役立つ航路が集まり次第、達成状況と新しさを見て紹介します。',
          GuildDiscoverySection.recent => '公開審査を通った新しい航路だけを、ここへ届けます。',
          GuildDiscoverySection.seekingCompanions =>
            '参加は任意です。まずは自分のQuestから始められます。',
        };
}

class _PublicationSheet extends StatefulWidget {
  const _PublicationSheet({required this.quests});

  final List<Quest> quests;

  @override
  State<_PublicationSheet> createState() => _PublicationSheetState();
}

class _PublicationSheetState extends State<_PublicationSheet> {
  final TextEditingController _summaryController = TextEditingController();
  late Quest _selectedQuest;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _selectedQuest = widget.quests.first;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboardHeight;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SizedBox(
        height: availableHeight * 0.85,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Questの公開申請',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedQuest.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '公開するQuest'),
                    items: [
                      for (final quest in widget.quests)
                        DropdownMenuItem(
                          value: quest.id,
                          child: Text(
                            quest.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      setState(() {
                        _selectedQuest = widget.quests.firstWhere(
                          (quest) => quest.id == id,
                        );
                        _confirmed = false;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _summaryController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: '公開用の概要',
                      hintText: 'ほかの人が挑戦を理解できるように、内容をまとめてください',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const Text('Quest名と表示名が公開候補になります。住所・連絡先などの個人情報は書かないでください。'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('公開する内容を確認しました'),
                    value: _confirmed,
                    onChanged: (value) =>
                        setState(() => _confirmed = value ?? false),
                  ),
                  FilledButton(
                    onPressed:
                        _confirmed && _summaryController.text.trim().isNotEmpty
                        ? () => Navigator.of(context).pop((
                            quest: _selectedQuest,
                            summary: _summaryController.text.trim(),
                          ))
                        : null,
                    child: const Text('審査へ提出する'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('キャンセル'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({this.cohort});

  final String? cohort;

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
          if (cohort != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'Guild Pilot参加中',
              child: const Chip(
                avatar: Icon(Icons.science_outlined, size: 18),
                label: Text('限定Pilot'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PilotGate extends StatelessWidget {
  const _PilotGate({required this.status});

  final GuildPilotStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ArcEmptyState(
          title: status.configured ? 'Guild Pilotを準備しています' : 'ローカルプレビュー',
          message: status.configured
              ? '安全性を確認しながら少人数で試しています。参加が有効になるまで、Questは公開されません。'
              : 'Supabaseへ接続すると、参加が許可されたNavigatorだけGuild Pilotを確認できます。',
          emotion: ArcEmotion.support,
          icon: Icons.lock_outline_rounded,
          actionLabel: 'Questへ戻る',
          onAction: () => context.go(AppRoutes.quest),
        ),
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
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(84, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.deepNavy
                : AppColors.white,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.parchment
                : AppColors.midnightNavy,
          ),
        ),
        segments: GuildDiscoverySection.values
            .map(
              (section) => ButtonSegment<GuildDiscoverySection>(
                value: section,
                label: Text(_sectionLabel(section), softWrap: false),
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
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.home),
              icon: const Icon(Icons.home_outlined),
              label: const Text('ホームへ戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
