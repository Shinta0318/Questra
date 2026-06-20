import 'package:flutter/material.dart';

import '../../core/theme/questra_colors.dart';
import '../questra_card.dart';
import 'arc_emotion.dart';
import 'arc_widget.dart';

class ArcEmptyState extends StatelessWidget {
  const ArcEmptyState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.emotion = ArcEmotion.lonely,
    this.icon = Icons.auto_awesome_outlined,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final ArcEmotion emotion;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArcWidget(emotion: emotion, size: 88, message: message),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'ここには、あなたの航路が少しずつ集まっていきます。',
            style: TextStyle(color: QuestraColors.slate),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(icon),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
