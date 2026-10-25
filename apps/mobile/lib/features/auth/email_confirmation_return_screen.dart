import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'auth_controller.dart';
import 'auth_journey_scaffold.dart';
import 'signup_confirmation_service.dart';

class EmailConfirmationReturnScreen extends ConsumerWidget {
  const EmailConfirmationReturnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final status = auth.signupConfirmationStatus;
    final checking =
        status == SignupConfirmationStatus.checking ||
        (status == SignupConfirmationStatus.verified && auth.isLoading);
    final unavailable =
        status == SignupConfirmationStatus.unavailable ||
        (status == SignupConfirmationStatus.verified &&
            !auth.isLoading &&
            !auth.isAuthenticated);
    return AuthJourneyScaffold(
      eyebrow: 'メール確認',
      title: checking ? 'メールを確認しています' : 'メール確認',
      message: '確認ができたら、そのままQuestraへ進みます。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (checking ||
              (status == SignupConfirmationStatus.verified &&
                  auth.isAuthenticated)) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'アカウントを確認しています。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.white),
            ),
          ] else ...[
            Text(
              unavailable
                  ? '確認を完了できませんでした。通信状態を確認し、もう一度メールのリンクを開いてください。'
                  : 'この確認リンクは使用済みか期限切れです。新しい確認メールを送信してください。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go(AppRoutes.confirmEmailHelp),
              child: const Text('確認メールを再送する'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('確認済みの方はログイン'),
            ),
          ],
        ],
      ),
    );
  }
}
