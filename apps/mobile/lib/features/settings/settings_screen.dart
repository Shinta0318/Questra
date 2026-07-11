import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../arc_memory/arc_memory_management_preview_service.dart';
import '../onboarding/onboarding_tour_controller.dart';
import '../trust/consent_purpose_registry_service.dart';
import '../trust/data_request_copy_service.dart';
import '../trust/trust_privacy_review_service.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustReview = const TrustPrivacyReviewService().buildReview();
    final memoryPreview = const ArcMemoryManagementPreviewService()
        .buildPreview();
    final dataRequests = const DataRequestCopyService().buildReview();
    final consentRegistry = const ConsentPurposeRegistryService()
        .buildRegistry();

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
              const SizedBox(height: AppSpacing.lg),
              _ArcMemoryManagementPreviewCard(preview: memoryPreview),
              const SizedBox(height: AppSpacing.lg),
              _DataRequestCopyCard(review: dataRequests),
              const SizedBox(height: AppSpacing.lg),
              _ConsentPurposeRegistryCard(registry: consentRegistry),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentPurposeRegistryCard extends StatelessWidget {
  const _ConsentPurposeRegistryCard({required this.registry});

  final ConsentPurposeRegistry registry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.84),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.28)),
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
                  color: AppColors.skyBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.skyBlue.withValues(alpha: 0.34),
                  ),
                ),
                child: const Icon(
                  Icons.rule_outlined,
                  color: AppColors.skyBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registry.heading,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      registry.summary,
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
          ...registry.purposes.map(
            (purpose) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ConsentPurposeTile(purpose: purpose),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: registry.guardrails
                .map(
                  (guardrail) => Chip(
                    label: Text(guardrail),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.24),
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

class _ConsentPurposeTile extends StatelessWidget {
  const _ConsentPurposeTile({required this.purpose});

  final ConsentPurposeDefinition purpose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_consentPurposeIcon(purpose.purpose), color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  purpose.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                purpose.defaultStateLabel,
                style: const TextStyle(
                  color: AppColors.skyBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            purpose.summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchment,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: purpose.dataScope
                .map(
                  (scope) => Chip(
                    label: Text(scope),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.white.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: AppColors.skyBlue.withValues(alpha: 0.2),
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

class _DataRequestCopyCard extends StatelessWidget {
  const _DataRequestCopyCard({required this.review});

  final DataRequestCopyReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.84),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
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
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.34),
                  ),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
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
          ...review.requests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DataRequestTile(request: request),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SafetyNoteBlock(notes: review.safetyNotes),
        ],
      ),
    );
  }
}

class _DataRequestTile extends StatelessWidget {
  const _DataRequestTile({required this.request});

  final DataRequestCopy request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_dataRequestIcon(request.type), color: AppColors.skyBlue),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                request.statusLabel,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            request.summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchment,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: request.scope
                .map(
                  (scope) => Chip(
                    label: Text(scope),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.white.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: AppColors.skyBlue.withValues(alpha: 0.2),
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

class _SafetyNoteBlock extends StatelessWidget {
  const _SafetyNoteBlock({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppColors.gold,
                size: 18,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                '安全な実装条件',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                note,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.parchment,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcMemoryManagementPreviewCard extends StatelessWidget {
  const _ArcMemoryManagementPreviewCard({required this.preview});

  final ArcMemoryManagementPreview preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.82),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.28)),
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
                  color: AppColors.skyBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.skyBlue.withValues(alpha: 0.36),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.skyBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.heading,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      preview.summary,
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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: preview.typePreviews
                .map((type) => _ArcMemoryTypeChip(type: type))
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...preview.actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ArcMemoryActionTile(action: action),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcMemoryTypeChip extends StatelessWidget {
  const _ArcMemoryTypeChip({required this.type});

  final ArcMemoryTypePreview type;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            type.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.parchment,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcMemoryActionTile extends StatelessWidget {
  const _ArcMemoryActionTile({required this.action});

  final ArcMemoryManagementItem action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_arcMemoryActionIcon(action.action), color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  action.summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchment,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            action.statusLabel,
            style: const TextStyle(
              color: AppColors.skyBlue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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

IconData _arcMemoryActionIcon(ArcMemoryManagementAction action) {
  return switch (action) {
    ArcMemoryManagementAction.review => Icons.visibility_outlined,
    ArcMemoryManagementAction.delete => Icons.delete_outline,
    ArcMemoryManagementAction.sensitivity => Icons.tune_outlined,
    ArcMemoryManagementAction.export => Icons.file_download_outlined,
  };
}

IconData _dataRequestIcon(DataRequestType type) {
  return switch (type) {
    DataRequestType.export => Icons.file_download_outlined,
    DataRequestType.deletion => Icons.delete_outline,
    DataRequestType.correction => Icons.edit_note_outlined,
    DataRequestType.withdrawal => Icons.undo_outlined,
  };
}

IconData _consentPurposeIcon(ConsentPurpose purpose) {
  return switch (purpose) {
    ConsentPurpose.questSupport => Icons.volunteer_activism_outlined,
    ConsentPurpose.productAnalytics => Icons.query_stats_outlined,
    ConsentPurpose.aiQualityReview => Icons.auto_fix_high_outlined,
    ConsentPurpose.externalConnection => Icons.link_outlined,
  };
}
