import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/forms/questra_field_label.dart';
import 'auth_journey_scaffold.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthJourneyScaffold(
      eyebrow: 'おかえりなさい',
      title: '航海を続けよう',
      message: 'おかえり、キャプテン。\n次の星への航路を、一緒に見つけよう。',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (auth.registrationCompleted)
                const _AuthNotice(
                  message: 'アカウントを作成しました。確認メールの案内後、登録したログインIDでログインしてください。',
                ),
              if (auth.passwordResetCompleted)
                const _AuthNotice(message: 'パスワードを更新しました。新しいパスワードでログインしてください。'),
              QuestraFieldLabel(
                label: 'ログインIDまたはメールアドレス',
                foregroundColor: AppColors.white,
                required: true,
                child: TextFormField(
                  controller: _identifierController,
                  decoration: _fieldDecoration(icon: Icons.badge_outlined),
                  style: const TextStyle(color: AppColors.white),
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  maxLength: InputLimits.email,
                  validator: InputValidators.loginIdentifier,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              QuestraFieldLabel(
                label: 'パスワード',
                foregroundColor: AppColors.white,
                required: true,
                child: TextFormField(
                  controller: _passwordController,
                  decoration: _fieldDecoration(
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      tooltip: _passwordVisible ? 'パスワードを隠す' : 'パスワードを表示',
                    ),
                  ),
                  style: const TextStyle(color: AppColors.white),
                  obscureText: !_passwordVisible,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => auth.isLoading ? null : _submit(),
                  autofillHints: const [AutofillHints.password],
                  maxLength: InputLimits.password,
                  buildCounter: _hiddenCounter,
                  validator: InputValidators.loginPassword,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () => context.go(AppRoutes.forgotPassword),
                  child: const Text('パスワードを忘れた方'),
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
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(auth.isLoading ? '確認しています' : 'ログイン'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: auth.isLoading
                    ? null
                    : () => context.go(AppRoutes.signup),
                child: const Text('新しく航海を始める'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'ログインすると、Quest・Mission・Task・Trailの続きから再開できます。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.62),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required IconData icon, Widget? suffix}) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: AppColors.skyBlue),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.midnightNavy,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.skyBlue.withValues(alpha: 0.24),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );

    if (mounted && ref.read(authControllerProvider).isAuthenticated) {
      final profile = ref.read(authControllerProvider).profile;
      context.go(
        profile?.onboardingCompleted == true
            ? AppRoutes.home
            : AppRoutes.onboarding,
      );
    }
  }
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cosmicBlue.withValues(alpha: 0.24),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.white, height: 1.5),
      ),
    );
  }
}

Widget? _hiddenCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;
