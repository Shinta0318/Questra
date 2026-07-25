import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/arc/arc_asset_paths.dart';

class AuthJourneyScaffold extends StatelessWidget {
  const AuthJourneyScaffold({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.child,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;

          if (wide) {
            return Row(
              children: [
                Expanded(flex: 11, child: _ArcVoyagePanel(message: message)),
                Expanded(
                  flex: 9,
                  child: _AuthPanel(
                    eyebrow: eyebrow,
                    title: title,
                    child: child,
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 270,
                  child: _ArcVoyagePanel(message: message, compact: true),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _AuthPanel(eyebrow: eyebrow, title: title, child: child),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArcVoyagePanel extends StatelessWidget {
  const _ArcVoyagePanel({required this.message, this.compact = false});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          ArcAssetPaths.approvedPortrait,
          fit: BoxFit.cover,
          alignment: compact ? const Alignment(0, -0.08) : Alignment.center,
          filterQuality: FilterQuality.high,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x18071426), Color(0xE6071426)],
              stops: [0.42, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(compact ? AppSpacing.xl : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _QuestraWordmark(),
                const Spacer(),
                Text(
                  message,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.eyebrow,
    required this.title,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.deepNavy,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    eyebrow,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestraWordmark extends StatelessWidget {
  const _QuestraWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.deepNavy.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          child: const Icon(Icons.explore_rounded, color: AppColors.gold),
        ),
        const SizedBox(width: AppSpacing.md),
        const Text(
          'Questra',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
