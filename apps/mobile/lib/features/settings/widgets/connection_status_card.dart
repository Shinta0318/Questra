import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../connection_status_service.dart';

class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({
    required this.snapshot,
    required this.onOpenArc,
    super.key,
  });

  final ConnectionStatusSnapshot snapshot;
  final VoidCallback onOpenArc;

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
          Text(
            '接続状態',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            snapshot.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.parchment,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _CapabilityRow(
            icon: Icons.cloud_done_outlined,
            capability: snapshot.dataStorage,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CapabilityRow(
            icon: Icons.auto_awesome_outlined,
            capability: snapshot.arcConversation,
          ),
          if (snapshot.arcConversation.state ==
              ConnectionCapabilityState.actionRequired) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('connection_status_open_arc'),
              onPressed: onOpenArc,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Arcで応答を確認'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.icon, required this.capability});

  final IconData icon;
  final ConnectionCapability capability;

  @override
  Widget build(BuildContext context) {
    final accent = switch (capability.state) {
      ConnectionCapabilityState.available => AppColors.auroraTeal,
      ConnectionCapabilityState.actionRequired => AppColors.gold,
      ConnectionCapabilityState.preview => AppColors.skyBlue,
      ConnectionCapabilityState.unavailable => AppColors.parchment,
    };

    return Semantics(
      label:
          '${capability.title}、${capability.statusLabel}。${capability.detail}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.deepNavy.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, semanticLabel: capability.title),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          capability.title,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        capability.statusLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    capability.detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.parchment,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
