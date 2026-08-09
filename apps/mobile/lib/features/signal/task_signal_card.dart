import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'task_signal_model.dart';

class TaskSignalCard extends StatelessWidget {
  const TaskSignalCard({required this.signal, required this.onOpen, super.key});

  final TaskSignal signal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = switch (signal.severity) {
      TaskSignalSeverity.urgent => AppColors.gold,
      TaskSignalSeverity.focus => AppColors.skyBlue,
      TaskSignalSeverity.calm => AppColors.parchment,
    };
    return Semantics(
      container: true,
      label: '${signal.title}。${signal.message}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.midnightNavy.withValues(alpha: 0.72),
          borderRadius: AppRadius.card,
          border: Border.all(color: color.withValues(alpha: 0.34)),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signal.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    signal.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.parchment,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onOpen,
              tooltip: 'Taskを開く',
              icon: const Icon(Icons.arrow_forward),
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
