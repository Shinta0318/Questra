import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../arc_memory/arc_memory_management_preview_service.dart';

class ArcMemoryManagementPreviewCard extends StatelessWidget {
  const ArcMemoryManagementPreviewCard({
    required this.preview,
    this.onOpen,
    super.key,
  });

  final ArcMemoryManagementPreview preview;
  final VoidCallback? onOpen;

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
          if (onOpen != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('記憶を管理'),
            ),
          ],
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
          Icon(_actionIcon(action.action), color: AppColors.gold),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              action.statusLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.skyBlue,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _actionIcon(ArcMemoryManagementAction action) {
  return switch (action) {
    ArcMemoryManagementAction.review => Icons.visibility_outlined,
    ArcMemoryManagementAction.delete => Icons.delete_outline,
    ArcMemoryManagementAction.sensitivity => Icons.tune_outlined,
    ArcMemoryManagementAction.export => Icons.file_download_outlined,
  };
}
