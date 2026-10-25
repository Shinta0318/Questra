import 'dart:async';

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
import 'auth_state.dart';

final confirmationEmailAvailableProvider = authEmailAvailableProvider;

class ConfirmEmailHelpScreen extends ConsumerStatefulWidget {
  const ConfirmEmailHelpScreen({super.key});

  @override
  ConsumerState<ConfirmEmailHelpScreen> createState() =>
      _ConfirmEmailHelpScreenState();
}

class _ConfirmEmailHelpScreenState
    extends ConsumerState<ConfirmEmailHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _requestAccepted = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final available = ref.watch(confirmationEmailAvailableProvider);
    final suggestedEmail = InputValidators.suggestedEmailCorrection(
      _emailController.text,
    );

    return AuthJourneyScaffold(
      eyebrow: '確認メール',
      title: 'メールが届かないとき',
      message: '登録時の宛先を確かめて、必要なら確認メールを再送できます。',
      child: !available
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'このモックでは確認メールを送信できません。',
                  style: TextStyle(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton(
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
                  Text(
                    '迷惑メールフォルダも確認してください。登録時に宛先を間違えた場合、再送では宛先を変更できません。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.white,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  QuestraFieldLabel(
                    label: '登録メールアドレス',
                    foregroundColor: AppColors.white,
                    required: true,
                    child: TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.skyBlue,
                        ),
                        filled: true,
                        fillColor: AppColors.midnightNavy,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.skyBlue.withValues(alpha: 0.24),
                          ),
                        ),
                      ),
                      style: const TextStyle(color: AppColors.white),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      maxLength: InputLimits.email,
                      onChanged: (_) =>
                          setState(() => _requestAccepted = false),
                      validator: InputValidators.email,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                  if (suggestedEmail != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          _emailController.text = suggestedEmail;
                          _emailController.selection = TextSelection.collapsed(
                            offset: suggestedEmail.length,
                          );
                          setState(() => _requestAccepted = false);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text('@${suggestedEmail.split('@').last} に修正する'),
                      ),
                    ),
                  ],
                  if (auth.errorContext == AuthErrorContext.confirmation &&
                      auth.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AuthErrorNotice(message: auth.errorMessage!),
                  ],
                  if (_requestAccepted) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: const Text(
                        '再送を受け付けました。メールの到着を確認してください。',
                        style: TextStyle(color: AppColors.white),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: auth.isLoading || _cooldownSeconds > 0
                        ? null
                        : _submit,
                    icon: auth.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      auth.isLoading
                          ? '確認しています'
                          : _cooldownSeconds > 0
                          ? '$_cooldownSeconds秒後に再送できます'
                          : '確認メールを再送する',
                    ),
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
    if (!ref.read(confirmationEmailAvailableProvider) ||
        ref.read(authControllerProvider).isLoading ||
        _cooldownSeconds > 0 ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final accepted = await ref
        .read(authControllerProvider.notifier)
        .resendSignupConfirmation(email: _emailController.text.trim());
    if (!mounted || !accepted) return;

    setState(() {
      _requestAccepted = true;
      _cooldownSeconds = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds == 0) timer.cancel();
    });
  }
}
