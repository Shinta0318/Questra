import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/onboarding/onboarding_tour_controller.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';

class QuestraOnboardingTour extends ConsumerStatefulWidget {
  const QuestraOnboardingTour({super.key});

  @override
  ConsumerState<QuestraOnboardingTour> createState() =>
      _QuestraOnboardingTourState();
}

class _QuestraOnboardingTourState extends ConsumerState<QuestraOnboardingTour> {
  int _stepIndex = 0;

  static const _steps = [
    _TourStep(
      title: 'Questraへようこそ',
      message: 'ここは君のQuestを見つける星図だよ。Arcと一緒に、今日の一歩を探していこう。',
      emotion: ArcEmotion.excited,
    ),
    _TourStep(
      title: 'Questを灯す',
      message: 'まずは叶えたいことをQuestとして登録してみよう。大きな夢も、まだ形のない願いも大丈夫。',
      emotion: ArcEmotion.support,
    ),
    _TourStep(
      title: 'Missionに分ける',
      message: 'Questを進める小さな一歩がMissionだよ。迷ったらArcが次の航路を一緒に描くよ。',
      emotion: ArcEmotion.support,
    ),
    _TourStep(
      title: 'Trailを残す',
      message: '進んだ記録はTrailとして残していこう。続けた時間も、立ち止まった理由も、君の資産になる。',
      emotion: ArcEmotion.normal,
    ),
    _TourStep(
      title: '迷ったらArcへ',
      message: 'HomeからArcへ、そしてQuestへ。いつでも話しかけて。次の星を一緒に見つけよう。',
      emotion: ArcEmotion.celebrate,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_stepIndex];
    final isLast = _stepIndex == _steps.length - 1;

    return Positioned.fill(
      child: Material(
        color: AppColors.deepNavy.withValues(alpha: 0.74),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: AppGradients.adventure,
                    borderRadius: AppRadius.glassCard,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.30),
                    ),
                    boxShadow: AppShadows.goldGlow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: ArcWidget(
                          emotion: step.emotion,
                          size: 128,
                          showSpeechBubble: false,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        step.message,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.parchment,
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          for (var index = 0; index < _steps.length; index++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: index == _stepIndex ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: index == _stepIndex
                                    ? AppColors.gold
                                    : AppColors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: _dismiss,
                            child: const Text('スキップ'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: isLast
                                ? _dismiss
                                : () => setState(() => _stepIndex += 1),
                            icon: Icon(
                              isLast
                                  ? Icons.check_circle_outline
                                  : Icons.arrow_forward,
                            ),
                            label: Text(isLast ? '始める' : '次へ'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _dismiss() {
    ref.read(onboardingTourControllerProvider.notifier).dismiss();
    ref.read(authControllerProvider.notifier).markOnboardingTourSeen();
  }
}

class _TourStep {
  const _TourStep({
    required this.title,
    required this.message,
    required this.emotion,
  });

  final String title;
  final String message;
  final ArcEmotion emotion;
}
