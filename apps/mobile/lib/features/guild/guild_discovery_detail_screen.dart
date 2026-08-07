import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import 'guild_discovery_model.dart';

class GuildDiscoveryDetailScreen extends StatelessWidget {
  const GuildDiscoveryDetailScreen({
    required this.quest,
    required this.recommendationReason,
    this.onCopy,
    super.key,
  });

  final GuildDiscoveryQuest quest;
  final String recommendationReason;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(title: const Text('公開Quest')),
      body: QuestraScreenSurface(
        child: QuestraResponsiveListView(
          showScrollbar: true,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          children: [
            Text(
              quest.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Navigator ${quest.authorDisplayName}',
              style: const TextStyle(color: AppColors.skyBlue),
            ),
            const SizedBox(height: 20),
            _DetailSection(title: '航路の概要', child: Text(quest.summary)),
            const SizedBox(height: 12),
            _DetailSection(title: '見つかった理由', child: Text(recommendationReason)),
            const SizedBox(height: 12),
            _DetailSection(
              title: '目安',
              child: Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  Text('難易度 ${quest.difficultyScore}/5'),
                  if (quest.estimatedDurationDays != null)
                    Text('推定 ${quest.estimatedDurationDays}日'),
                  if (quest.estimatedCostLabel != null)
                    Text('費用 ${quest.estimatedCostLabel}'),
                ],
              ),
            ),
            if (quest.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailSection(
                title: 'Quest DNA',
                child: Text(quest.tags.join('  ·  ')),
              ),
            ],
            const SizedBox(height: 12),
            _DetailSection(
              title: '公開情報',
              child: Text(
                '航路への派生 ${quest.copyCount}件  ·  達成 ${quest.completionCount}件  ·  レビュー ${quest.reviewCount}件',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.call_split_rounded),
              label: Text(onCopy == null ? 'コピー機能を準備中' : '自分のQuestに取り入れる'),
            ),
            const SizedBox(height: 10),
            Text(
              '取り入れる前に内容を確認し、Arcの最適化を選べるようになります。',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.parchment),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.deepNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: const TextStyle(color: AppColors.deepNavy),
            child: child,
          ),
        ],
      ),
    );
  }
}
