import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../horizon/horizon_next_challenge_service.dart';

class HomeHorizonCard extends StatelessWidget {
  const HomeHorizonCard({
    super.key,
    required this.challenge,
    required this.onAction,
  });

  final HorizonNextChallenge challenge;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.74),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.22)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.public, color: AppColors.gold, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.readinessLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  challenge.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchment,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(challenge.suggestedAction),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
