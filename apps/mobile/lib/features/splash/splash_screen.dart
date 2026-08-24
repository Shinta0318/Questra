import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/supabase_config.dart';
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
    final persistenceUnavailable = !SupabaseConfig.persistenceAvailable;
    final usesLocalData =
        SupabaseConfig.persistenceSource == PersistenceSource.localDevelopment;
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
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: AppColors.white,
                                height: 1.18,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'ArcとともにQuestを見つけ、Missionへ進み、Trailを残そう。',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.82),
                                height: 1.6,
                              ),
                        ),
                        if (persistenceUnavailable || usesLocalData) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _PersistenceNotice(
                            unavailable: persistenceUnavailable,
                          ),
                        ],
                        if (auth.errorMessage != null &&
                            SupabaseConfig.isConfigured) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _SessionFailureNotice(
                            message: auth.errorMessage!,
                            onRetry: () => ref
                                .read(authControllerProvider.notifier)
                                .restoreSession(),
                            onSignOut: _signOutAndLogin,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        FilledButton.icon(
                          onPressed: auth.isLoading || persistenceUnavailable
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
                                : persistenceUnavailable
                                ? '接続設定を確認してください'
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

  Future<void> _signOutAndLogin() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go(AppRoutes.login);
  }
}

class _PersistenceNotice extends StatelessWidget {
  const _PersistenceNotice({required this.unavailable});

  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final icon = unavailable
        ? Icons.cloud_off_outlined
        : Icons.developer_mode_outlined;
    final title = unavailable ? 'データ保存を開始できません' : '開発用データで表示中';
    final message = unavailable
        ? 'Supabaseの接続設定を確認してください。保存先がない状態では航海を開始できません。'
        : 'この端末内だけに保存されます。正式なアカウントデータとは同期されません。';

    return Semantics(
      container: true,
      liveRegion: unavailable,
      label: '$title。$message',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.deepNavy.withValues(alpha: 0.82),
          border: Border.all(
            color:
                (unavailable ? AppColors.notificationError : AppColors.skyBlue)
                    .withValues(alpha: 0.72),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: unavailable
                  ? AppColors.notificationError
                  : AppColors.skyBlue,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.82),
                      height: 1.5,
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

class _SessionFailureNotice extends StatelessWidget {
  const _SessionFailureNotice({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.deepNavy.withValues(alpha: 0.88),
          border: Border.all(
            color: AppColors.notificationError.withValues(alpha: 0.72),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.white,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(onPressed: onRetry, child: const Text('もう一度確認')),
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('別のアカウントでログイン'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
