import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/forms/questra_field_label.dart';
import 'auth_controller.dart';
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

    return AuthJourneyScaffold(
      eyebrow: '新しいパスワードを設定',
      title: '新しい鍵を決める',
      message: 'これからの航路を守る、新しいパスワードを設定してください。',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestraFieldLabel(
              label: '新しいパスワード',
              foregroundColor: AppColors.white,
              required: true,
              child: TextFormField(
                controller: _passwordController,
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
                decoration: _passwordDecoration(),
                style: const TextStyle(color: AppColors.white),
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.done,
                maxLength: InputLimits.password,
                validator: (value) => InputValidators.passwordConfirmation(
                  value,
                  _passwordController.text,
                ),
                onFieldSubmitted: (_) => auth.isLoading ? null : _submit(),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                auth.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
    prefixIcon: const Icon(Icons.lock_outline_rounded),
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
    if (mounted && ref.read(authControllerProvider).passwordResetCompleted) {
      context.go(AppRoutes.login);
    }
  }
}
