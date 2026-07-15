import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';
import '../questra_card.dart';
import '../questra_primary_button.dart';
import 'questra_responsive_list_view.dart';
import 'questra_screen_surface.dart';

class QuestraComingSoonScreen extends StatelessWidget {
  const QuestraComingSoonScreen({
    required this.featureName,
    required this.message,
    this.emotion = ArcEmotion.support,
    super.key,
  });

  final String featureName;
  final String message;
  final ArcEmotion emotion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: QuestraScreenSurface(
        child: QuestraResponsiveListView(
          maxContentWidth: 640,
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArcWidget(
                    emotion: emotion,
                    size: 96,
                    showSpeechBubble: false,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    featureName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(message, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
                  const Chip(label: Text('Coming Soon')),
                  const SizedBox(height: AppSpacing.xl),
                  QuestraPrimaryButton(
                    label: 'Homeへ戻る',
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
