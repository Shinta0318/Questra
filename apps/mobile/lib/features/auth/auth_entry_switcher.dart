import 'package:flutter/material.dart';

import '../../core/accessibility/questra_accessibility.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

enum AuthEntryMode { login, signup }

class AuthEntrySwitcher extends StatelessWidget {
  const AuthEntrySwitcher({
    required this.selected,
    required this.onLogin,
    required this.onSignup,
    super.key,
  });

  final AuthEntryMode selected;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: QuestraAccessibility.minTapTarget,
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy,
        borderRadius: AppRadius.button,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.64)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthEntryOption(
              key: const Key('auth-entry-login'),
              labelKey: const Key('auth-entry-login-label'),
              icon: Icons.login_rounded,
              label: 'ログイン',
              selected: selected == AuthEntryMode.login,
              onTap: onLogin,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _AuthEntryOption(
              key: const Key('auth-entry-signup'),
              labelKey: const Key('auth-entry-signup-label'),
              icon: Icons.person_add_alt_1_outlined,
              label: '新規登録',
              selected: selected == AuthEntryMode.signup,
              onTap: onSignup,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthEntryOption extends StatelessWidget {
  const _AuthEntryOption({
    required this.labelKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Key labelKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.deepNavy : AppColors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.cloud : Colors.transparent,
        borderRadius: AppRadius.button,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selected ? null : onTap,
          focusColor: AppColors.gold.withValues(alpha: 0.18),
          hoverColor: AppColors.skyBlue.withValues(alpha: 0.12),
          child: ConstrainedBox(
            constraints: QuestraAccessibility.minTapTargetConstraints,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      key: labelKey,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
