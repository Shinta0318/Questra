import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'legal_policy.dart';

class LegalEligibilityForm extends StatefulWidget {
  const LegalEligibilityForm({
    required this.onAccepted,
    this.submitLabel = '内容を確認して進む',
    this.dark = false,
    super.key,
  });

  final ValueChanged<LegalAcceptance> onAccepted;
  final String submitLabel;
  final bool dark;

  @override
  State<LegalEligibilityForm> createState() => _LegalEligibilityFormState();
}

class _LegalEligibilityFormState extends State<LegalEligibilityForm> {
  bool _ageConfirmed = false;
  bool _regionConfirmed = false;
  bool _aiUnderstood = false;
  bool _termsAccepted = false;

  bool get _canContinue =>
      _ageConfirmed && _regionConfirmed && _aiUnderstood && _termsAccepted;

  @override
  Widget build(BuildContext context) {
    final foreground = widget.dark ? AppColors.white : null;
    final secondary = widget.dark
        ? AppColors.white.withValues(alpha: 0.72)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '入力を始める前に',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Questraは${QuestraLegalPolicy.regionLabel}として提供しています。年齢条件とデータの扱いを確認してください。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: secondary, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        _check(
          value: _ageConfirmed,
          onChanged: (value) => setState(() => _ageConfirmed = value),
          title: '${QuestraLegalPolicy.minimumAge}歳以上です',
          subtitle: '現在の外部Betaは18歳未満の方を対象としていません。',
          foreground: foreground,
          secondary: secondary,
        ),
        _check(
          value: _regionConfirmed,
          onChanged: (value) => setState(() => _regionConfirmed = value),
          title: '日本向けBetaとして利用します',
          subtitle: '対象地域外への一般提供は、地域ごとの法務確認後に行います。',
          foreground: foreground,
          secondary: secondary,
        ),
        _check(
          value: _aiUnderstood,
          onChanged: (value) => setState(() => _aiUnderstood = value),
          title: 'Arcの提案に外部AI処理が含まれることを理解しました',
          subtitle:
              '相談内容と許可されたQuest文脈は安全なサーバーを経由してGeminiへ送られます。提案は誤ることがあり、重要な判断は確認が必要です。',
          foreground: foreground,
          secondary: secondary,
        ),
        _check(
          value: _termsAccepted,
          onChanged: (value) => setState(() => _termsAccepted = value),
          title: '利用規約とプライバシー説明に同意します',
          subtitle:
              '利用規約 ${QuestraLegalPolicy.termsVersion} / Privacy ${QuestraLegalPolicy.privacyVersion}',
          foreground: foreground,
          secondary: secondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
            iconColor: widget.dark ? AppColors.skyBlue : null,
            collapsedIconColor: widget.dark ? AppColors.skyBlue : null,
            title: Text(
              'データ処理の要点を見る',
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
            ),
            children: [
              Text(
                'Supabaseは認証・保存に利用します。GeminiはArc ChatとQuest計画の生成時に利用します。'
                'Arc Memoryなどの目的別利用はSettingsで選択・撤回できます。機密情報は入力しないでください。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: secondary, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: _canContinue
              ? () => widget.onAccepted(QuestraLegalPolicy.acceptance())
              : null,
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(widget.submitLabel),
        ),
      ],
    );
  }

  Widget _check({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
    required Color? foreground,
    required Color secondary,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        title: Text(
          title,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: secondary, height: 1.45),
        ),
      ),
    );
  }
}
