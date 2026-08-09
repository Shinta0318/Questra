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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthJourneyScaffold(
      eyebrow: 'パスワード再設定',
      title: '航路を取り戻す',
      message: '登録したメールアドレスへ、パスワード再設定の案内を送ります。',
      child: auth.passwordResetRequested
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.gold,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '入力したメールアドレスに該当するアカウントがある場合、再設定メールを送信しました。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.white,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('ログインへ戻る'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuestraFieldLabel(
                    label: '登録メールアドレス',
                    foregroundColor: AppColors.white,
                    required: true,
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      style: const TextStyle(color: AppColors.white),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      maxLength: InputLimits.email,
                      validator: InputValidators.email,
                      onFieldSubmitted: (_) =>
                          auth.isLoading ? null : _submit(),
                    ),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      auth.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                        : const Icon(Icons.send_outlined),
                    label: Text(auth.isLoading ? '送信しています' : '再設定メールを送る'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('ログインへ戻る'),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email: _emailController.text.trim());
  }
}
