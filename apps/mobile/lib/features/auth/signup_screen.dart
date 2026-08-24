import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/forms/questra_field_label.dart';
import '../trust/legal_eligibility_form.dart';
import '../trust/legal_policy.dart';
import 'auth_journey_scaffold.dart';
import 'auth_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _loginIdController = TextEditingController();
  bool _passwordVisible = false;
  LegalAcceptance? _legalAcceptance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _loginIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (_legalAcceptance == null) {
      return AuthJourneyScaffold(
        eyebrow: '新しい航海を始める',
        title: '安心して始めるために',
        message: '君の願いを預かる前に、\n大切な約束を一緒に確認しよう。',
        child: LegalEligibilityForm(
          dark: true,
          submitLabel: 'アカウント情報を入力',
          onAccepted: (acceptance) =>
              setState(() => _legalAcceptance = acceptance),
        ),
      );
    }

    return AuthJourneyScaffold(
      eyebrow: '新しい航海を始める',
      title: '最初のQuestを灯そう',
      message: 'まだ名前のない願いも大丈夫。\nArcと一緒に、君だけの航路を描こう。',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LegalConfirmation(
                onReview: auth.isLoading
                    ? null
                    : () => setState(() => _legalAcceptance = null),
              ),
              const SizedBox(height: AppSpacing.lg),
              QuestraFieldLabel(
                label: 'Arcからの呼び名',
                foregroundColor: AppColors.white,
                required: true,
                child: TextFormField(
                  controller: _nicknameController,
                  decoration: _fieldDecoration(
                    icon: Icons.person_outline_rounded,
                  ),
                  style: const TextStyle(color: AppColors.white),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.nickname],
                  maxLength: InputLimits.nickname,
                  validator: (value) => InputValidators.requiredText(
                    value,
                    fieldName: 'Arcからの呼び名',
                    maxLength: InputLimits.nickname,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              QuestraFieldLabel(
                label: 'ログインID',
                foregroundColor: AppColors.white,
                helper: '半角英数字・._- を使って3〜40文字',
                required: true,
                child: TextFormField(
                  controller: _loginIdController,
                  decoration: _fieldDecoration(icon: Icons.badge_outlined),
                  style: const TextStyle(color: AppColors.white),
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  maxLength: InputLimits.loginId,
                  validator: InputValidators.loginId,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              QuestraFieldLabel(
                label: 'メールアドレス',
                foregroundColor: AppColors.white,
                required: true,
                child: TextFormField(
                  controller: _emailController,
                  decoration: _fieldDecoration(
                    icon: Icons.mail_outline_rounded,
                  ),
                  style: const TextStyle(color: AppColors.white),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  maxLength: InputLimits.email,
                  validator: InputValidators.email,
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
                  autofillHints: const [AutofillHints.newPassword],
                  maxLength: InputLimits.password,
                  buildCounter: _hiddenCounter,
                  validator: InputValidators.newPassword,
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
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(auth.isLoading ? '航路を準備しています' : '航海を始める'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () => context.go(AppRoutes.login),
                child: const Text('アカウントをお持ちの方はログイン'),
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
        .signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nickname: _nicknameController.text.trim(),
          loginId: _loginIdController.text.trim().toLowerCase(),
          legalAcceptance: _legalAcceptance!,
        );

    if (mounted && ref.read(authControllerProvider).registrationCompleted) {
      context.go(AppRoutes.login);
    }
  }
}

class _LegalConfirmation extends StatelessWidget {
  const _LegalConfirmation({required this.onReview});

  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cosmicBlue.withValues(alpha: 0.18),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.skyBlue),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              '年齢条件・利用規約・Privacy・AI処理を確認済み',
              style: TextStyle(color: AppColors.white),
            ),
          ),
          TextButton(onPressed: onReview, child: const Text('見直す')),
        ],
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
