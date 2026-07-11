import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../onboarding/onboarding_tour_controller.dart';
import '../trust/trust_privacy_review_service.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustReview = const TrustPrivacyReviewService().buildReview();

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.adventure),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                '設定',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.midnightNavy.withValues(alpha: 0.78),
                  borderRadius: AppRadius.glassCard,
                  border: Border.all(
                    color: AppColors.skyBlue.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ArcWidget(
                      emotion: ArcEmotion.support,
                      size: 72,
                      showSpeechBubble: false,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Arcチュートリアル',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Home、Arc、Questの流れをもう一度確認できます。迷ったときは、ここから星図を開き直せます。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.parchment,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: () => ref
                              .read(onboardingTourControllerProvider.notifier)
                              .replay(),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Arcチュートリアルを再表示'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.quest),
                          icon: const Icon(Icons.explore_outlined),
                          label: const Text('Questへ戻る'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _TrustPrivacyCard(review: trustReview),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustPrivacyCard extends StatelessWidget {
  const _TrustPrivacyCard({required this.review});

  final TrustPrivacyReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.82),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.36),
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.heading,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      review.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.parchment,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...review.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TrustPrivacyItemTile(item: item),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '今後追加する操作',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: review.futureActions
                .map(
                  (action) => Chip(
                    label: Text(action),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.white.withValues(alpha: 0.12),
                    side: BorderSide(
                      color: AppColors.skyBlue.withValues(alpha: 0.24),
                    ),
                    labelStyle: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _TrustPrivacyItemTile extends StatelessWidget {
  const _TrustPrivacyItemTile({required this.item});

  final TrustPrivacyReviewItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_trustIcon(item.area), color: AppColors.skyBlue, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  item.statusLabel,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchment,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.userControl,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.skyBlue,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _trustIcon(TrustPrivacyArea area) {
  return switch (area) {
    TrustPrivacyArea.journeyData => Icons.route_outlined,
    TrustPrivacyArea.arcMemory => Icons.auto_awesome_outlined,
    TrustPrivacyArea.aiTransparency => Icons.psychology_alt_outlined,
    TrustPrivacyArea.questSupport => Icons.volunteer_activism_outlined,
    TrustPrivacyArea.ownerBoundary => Icons.lock_outline,
  };
}
