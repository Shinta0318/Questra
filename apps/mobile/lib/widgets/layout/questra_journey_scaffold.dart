import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'questra_screen_surface.dart';

class QuestraJourneyScaffold extends StatelessWidget {
  const QuestraJourneyScaffold({
    required this.title,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(title: Text(title), actions: actions),
      body: QuestraScreenSurface(child: child),
      floatingActionButton: floatingActionButton,
    );
  }
}
