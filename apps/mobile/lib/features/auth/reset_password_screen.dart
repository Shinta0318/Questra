import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/forms/questra_field_label.dart';
import 'auth_controller.dart';
import 'auth_email_availability.dart';
import 'auth_error_notice.dart';
import 'auth_journey_scaffold.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final emailAvailable = ref.watch(authEmailAvailableProvider);

    return AuthJourneyScaffold(
      eyebrow: 'パスワード再設定',
      title: auth.passwordResetCompleted
          ? 'パスワードを更新しました'
          : emailAvailable && !auth.isPasswordRecovery
          ? '再設定リンクを確認'
          : '新しいパスワードを設定',
      message: emailAvailable
          ? auth.passwordResetSignOutPending
                ? 'パスワードは更新済みです。安全にログインし直すため、セッションを終了してください。'
                : auth.passwordResetCompleted
                ? '新しいパスワードでログインできます。'
                : auth.isPasswordRecovery
                ? '新しいパスワードを2回入力してください。'
                : 'リンクを確認できませんでした。最新の再設定メールから開き直してください。'
          : 'このオフラインモックではパスワードを再設定できません。',
      child: !emailAvailable
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '再設定リンクの確認はSupabaseに接続した画面で利用できます。',
                  style: TextStyle(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('ログインへ戻る'),
                ),
              ],
            )
          : auth.passwordResetSignOutPending
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'パスワードは変更されています。もう一度パスワードを入力する必要はありません。',
                  style: TextStyle(color: AppColors.white),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AuthErrorNotice(message: auth.errorMessage!),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: auth.isLoading ? null : _finishSignOut,
                  child: Text(auth.isLoading ? '終了しています' : 'セッションを終了してログインへ'),
                ),
              ],
            )
          : auth.passwordResetCompleted
          ? const Center(child: CircularProgressIndicator())
          : !auth.isPasswordRecovery
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  const Text(
                    'このリンクではパスワードを変更できません。再設定メールを送り直し、届いた最新のリンクを開いてください。',
                    style: TextStyle(color: AppColors.white),
                  ),
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: () => context.go(AppRoutes.forgotPassword),
                  child: const Text('再設定メールを送り直す'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuestraFieldLabel(
                    label: '新しいパスワード',
                    foregroundColor: AppColors.white,
                    required: true,
                    child: TextFormField(
                      controller: _passwordController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: _passwordDecoration(),
                      style: const TextStyle(color: AppColors.white),
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      maxLength: InputLimits.password,
                      validator: InputValidators.newPassword,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  QuestraFieldLabel(
                    label: '新しいパスワード（確認）',
                    foregroundColor: AppColors.white,
                    required: true,
                    child: TextFormField(
                      controller: _confirmationController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: _passwordDecoration(),
                      style: const TextStyle(color: AppColors.white),
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.done,
                      maxLength: InputLimits.password,
                      validator: (value) =>
                          InputValidators.passwordConfirmation(
                            value,
                            _passwordController.text,
                          ),
                      onFieldSubmitted: (_) =>
                          auth.isLoading ? null : _submit(),
                    ),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AuthErrorNotice(message: auth.errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: auth.isLoading ? null : _submit,
                    icon: auth.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset_rounded),
                    label: Text(auth.isLoading ? '更新しています' : 'パスワードを更新'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.forgotPassword),
                    child: const Text('再設定メールを送り直す'),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _passwordDecoration() => InputDecoration(
    prefixIcon: const Icon(
      Icons.lock_outline_rounded,
      color: AppColors.skyBlue,
    ),
    filled: true,
    fillColor: AppColors.midnightNavy,
    suffixIcon: IconButton(
      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
      icon: Icon(
        _passwordVisible
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
      ),
      tooltip: _passwordVisible ? 'パスワードを隠す' : 'パスワードを表示',
    ),
  );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .completePasswordReset(newPassword: _passwordController.text);
    final auth = ref.read(authControllerProvider);
    if (mounted &&
        auth.passwordResetCompleted &&
        !auth.passwordResetSignOutPending) {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _finishSignOut() async {
    await ref
        .read(authControllerProvider.notifier)
        .finishPasswordResetSignOut();
    if (mounted &&
        !ref.read(authControllerProvider).passwordResetSignOutPending) {
      context.go(AppRoutes.login);
    }
  }
}
