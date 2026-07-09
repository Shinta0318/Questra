import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../onboarding/onboarding_tour_controller.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            ],
          ),
        ),
      ),
    );
  }
}
