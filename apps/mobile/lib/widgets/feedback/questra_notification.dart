import 'package:flutter/material.dart';

import '../../core/accessibility/questra_accessibility.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

enum QuestraNotificationType { success, error, warning, info }

extension QuestraNotificationTypeVisuals on QuestraNotificationType {
  IconData get icon => switch (this) {
    QuestraNotificationType.success => Icons.check_circle_outline_rounded,
    QuestraNotificationType.error => Icons.error_outline_rounded,
    QuestraNotificationType.warning => Icons.warning_amber_rounded,
    QuestraNotificationType.info => Icons.info_outline_rounded,
  };

  Color get accent => switch (this) {
    QuestraNotificationType.success => AppColors.auroraTeal,
    QuestraNotificationType.error => AppColors.notificationError,
    QuestraNotificationType.warning => AppColors.warmGold,
    QuestraNotificationType.info => AppColors.skyBlue,
  };

  String get semanticLabel => switch (this) {
    QuestraNotificationType.success => '成功',
    QuestraNotificationType.error => 'エラー',
    QuestraNotificationType.warning => '警告',
    QuestraNotificationType.info => 'お知らせ',
  };
}

class QuestraNotification extends StatelessWidget {
  const QuestraNotification({
    required this.message,
    required this.type,
    this.onDismiss,
    this.isBusy = false,
    super.key,
  });

  final String message;
  final QuestraNotificationType type;
  final VoidCallback? onDismiss;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final accent = type.accent;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${type.semanticLabel}通知: $message',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.notificationSurface,
          borderRadius: AppRadius.button,
          border: Border.all(color: accent.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepNavy.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: isBusy
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: accent,
                      ),
                    )
                  : Icon(type.icon, color: accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                softWrap: true,
                style: const TextStyle(
                  color: AppColors.notificationText,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (onDismiss != null) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: onDismiss,
                tooltip: '通知を閉じる',
                constraints: QuestraAccessibility.minTapTargetConstraints,
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.notificationMuted,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

abstract final class QuestraSnackBars {
  static SnackBar message(
    String message, {
    QuestraNotificationType type = QuestraNotificationType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    return SnackBar(
      duration: duration,
      content: Row(
        children: [
          Icon(type.icon, color: type.accent, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, softWrap: true)),
        ],
      ),
    );
  }
}
