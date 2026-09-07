import 'dart:async';

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
  const QuestraOnboardingTour({
    this.entryPoint = OnboardingTourEntryPoint.automatic,
    super.key,
  });

  final OnboardingTourEntryPoint entryPoint;

  @override
  ConsumerState<QuestraOnboardingTour> createState() =>
      _QuestraOnboardingTourState();
}

class _QuestraOnboardingTourState extends ConsumerState<QuestraOnboardingTour> {
  int _stepIndex = 0;
  bool _isDismissing = false;
  bool _isAdvancing = false;
  FocusNode? _previousFocus;

  static const _steps = [
    _TourStep(
      title: 'Questraへようこそ',
      message: 'ここは君のQuestを見つける星図だよ。Arcと一緒に、今日の一歩を探していこう。',
      emotion: ArcEmotion.excited,
    ),
    _TourStep(
      title: 'Questを灯す',
      message: '叶えたいことをQuestとして言葉にしよう。大きな夢も、まだ形のない願いも大丈夫。',
      emotion: ArcEmotion.support,
    ),
    _TourStep(
      title: 'Missionで航路を決める',
      message: 'MissionはQuestへ近づく途中の到達点。Arcが順番と期限を整理し、進む航路を一緒に描くよ。',
      emotion: ArcEmotion.support,
    ),
    _TourStep(
      title: 'Taskから始める',
      message: 'Taskは今日から実行できる具体的な行動。終えた一歩はTrailとして残り、次の判断につながるよ。',
      emotion: ArcEmotion.normal,
    ),
    _TourStep(
      title: '迷ったらArcへ',
      message: 'HomeからArcへ、そしてQuestへ。状況が変わったときも、次の航路を一緒に見直そう。',
      emotion: ArcEmotion.celebrate,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _previousFocus = FocusManager.instance.primaryFocus;
  }

  @override
  void dispose() {
    final previousFocus = _previousFocus;
    if (previousFocus?.canRequestFocus ?? false) {
      scheduleMicrotask(previousFocus!.requestFocus);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_stepIndex];
    final isLast = _stepIndex == _steps.length - 1;

    return Positioned.fill(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _dismiss();
          }
        },
        child: Material(
          color: AppColors.deepNavy.withValues(alpha: 0.86),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final outerPadding = constraints.maxHeight < 520
                    ? AppSpacing.sm
                    : AppSpacing.lg;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        label: 'チュートリアルを閉じる',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _dismiss,
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(outerPadding),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Material(
                            key: const ValueKey('onboarding-tour-surface'),
                            color: AppColors.midnightNavy,
                            elevation: 12,
                            shadowColor: AppColors.gold.withValues(alpha: 0.24),
                            borderRadius: AppRadius.glassCard,
                            clipBehavior: Clip.antiAlias,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppGradients.adventure,
                                borderRadius: AppRadius.glassCard,
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.34),
                                ),
                                boxShadow: AppShadows.goldGlow,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      constraints.maxHeight - outerPadding * 2,
                                ),
                                child: Semantics(
                                  container: true,
                                  scopesRoute: true,
                                  namesRoute: true,
                                  explicitChildNodes: true,
                                  label:
                                      'Questraの使い方 ${_stepIndex + 1}/${_steps.length}',
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _TourHeader(
                                        currentStep: _stepIndex + 1,
                                        totalSteps: _steps.length,
                                        onClose: _dismiss,
                                      ),
                                      Flexible(
                                        child: SingleChildScrollView(
                                          key: const ValueKey(
                                            'onboarding-tour-scroll',
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.xl,
                                            AppSpacing.sm,
                                            AppSpacing.xl,
                                            AppSpacing.lg,
                                          ),
                                          child: _TourStepContent(step: step),
                                        ),
                                      ),
                                      _TourFooter(
                                        stepIndex: _stepIndex,
                                        stepCount: _steps.length,
                                        isLast: isLast,
                                        onSkip: _dismiss,
                                        onNext: _advance,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _advance() {
    if (_isDismissing || _isAdvancing) {
      return;
    }
    if (_stepIndex == _steps.length - 1) {
      _dismiss();
      return;
    }
    _isAdvancing = true;
    setState(() => _stepIndex += 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _isAdvancing = false;
      }
    });
  }

  void _dismiss() {
    if (_isDismissing) {
      return;
    }
    _isDismissing = true;
    final tourController = ref.read(onboardingTourControllerProvider.notifier);
    if (widget.entryPoint == OnboardingTourEntryPoint.automatic) {
      final authController = ref.read(authControllerProvider.notifier);
      unawaited(authController.markOnboardingTourSeen());
    }
    tourController.dismiss();
  }
}

class _TourHeader extends StatelessWidget {
  const _TourHeader({
    required this.currentStep,
    required this.totalSteps,
    required this.onClose,
  });

  final int currentStep;
  final int totalSteps;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$currentStep / $totalSteps',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.skyBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('onboarding-tour-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(Icons.close, color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _TourStepContent extends StatelessWidget {
  const _TourStepContent({required this.step});

  final _TourStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.center,
          child: ArcWidget(
            emotion: step.emotion,
            size: 112,
            showSpeechBubble: false,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          step.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          step.message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.parchment,
            height: 1.55,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TourFooter extends StatelessWidget {
  const _TourFooter({
    required this.stepIndex,
    required this.stepCount,
    required this.isLast,
    required this.onSkip,
    required this.onNext,
  });

  final int stepIndex;
  final int stepCount;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final animationDuration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Material(
      color: AppColors.midnightNavy.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < stepCount; index++)
                  AnimatedContainer(
                    duration: animationDuration,
                    width: index == stepIndex ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: index == stepIndex
                          ? AppColors.gold
                          : AppColors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: AppSpacing.sm,
              overflowSpacing: AppSpacing.xs,
              children: [
                TextButton(onPressed: onSkip, child: const Text('スキップ')),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: Icon(
                    isLast ? Icons.check_circle_outline : Icons.arrow_forward,
                  ),
                  label: Text(isLast ? '始める' : '次へ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
