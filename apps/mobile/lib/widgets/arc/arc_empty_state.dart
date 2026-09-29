import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/questra_surface_palette.dart';
import '../questra_card.dart';
import 'arc_emotion.dart';
import 'arc_widget.dart';

class ArcEmptyState extends StatelessWidget {
  const ArcEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    this.emotion = ArcEmotion.lonely,
    this.icon = Icons.auto_awesome_outlined,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;
  final ArcEmotion emotion;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: QuestraCard(
        palette: QuestraSurfacePalette.dark,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 300;
            final content = _EmptyStateContent(
              title: title,
              message: message,
              actionLabel: actionLabel,
              actionKey: actionKey,
              onAction: onAction,
              icon: icon,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArcWidget(
                    emotion: emotion,
                    size: 56,
                    showSpeechBubble: false,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  content,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArcWidget(emotion: emotion, size: 68, showSpeechBubble: false),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyStateContent extends StatelessWidget {
  const _EmptyStateContent({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
    required this.icon,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: actionKey,
              onPressed: onAction,
              icon: Icon(icon),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
