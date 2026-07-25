import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/arc/arc_asset_paths.dart';
import '../auth/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigationScheduled = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.isAuthenticated && !_navigationScheduled) {
      _navigationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _continueJourney());
    }

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            ArcAssetPaths.approvedPortrait,
            fit: BoxFit.cover,
            alignment: const Alignment(0.12, -0.08),
            filterQuality: FilterQuality.high,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x18071426),
                  Color(0x60071426),
                  Color(0xFA071426),
                ],
                stops: [0.2, 0.58, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        color: AppColors.gold,
                        size: 30,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Questra',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '挑戦が、\n君の星座になる。',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AppColors.white,
                                height: 1.18,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'ArcとともにQuestを見つけ、Missionへ進み、Trailを残そう。',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.82),
                                height: 1.6,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        FilledButton.icon(
                          onPressed: auth.isLoading
                              ? null
                              : auth.isAuthenticated
                                  ? _continueJourney
                                  : () => context.go(AppRoutes.login),
                          icon: auth.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            auth.isLoading
                                ? '航路を確認しています'
                                : auth.isAuthenticated
                                    ? '航海を続ける'
                                    : 'Arcとの航海を始める',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _continueJourney() {
    if (!mounted) return;
    final profile = ref.read(authControllerProvider).profile;
    context.go(
      profile?.onboardingCompleted == true
          ? AppRoutes.home
          : AppRoutes.onboarding,
    );
  }
}
