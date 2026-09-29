import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/questra_colors.dart';
import '../../core/theme/questra_surface_palette.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_bond_service.dart';
import '../arc/navigator_rank_service.dart';
import '../arc/stardust_service.dart';
import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../trail/trail_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final activeQuestCount = quests
        .where((quest) => quest.status == QuestStatus.active)
        .length;
    final openMissionCount = missions
        .where((mission) => mission.status == MissionStatus.todo)
        .length;
    final bond = ref
        .watch(arcBondServiceProvider)
        .resolve(profile?.bondScore ?? 0);
    final stardust = ref
        .watch(stardustServiceProvider)
        .resolve(profile?.stardustBalance ?? 0);
    final navigatorRank = ref
        .watch(navigatorRankServiceProvider)
        .resolve(stardustBalance: profile?.stardustBalance ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: '改善点を送る',
            onPressed: () => context.push(AppRoutes.feedback),
            icon: const Icon(Icons.feedback_outlined),
          ),
        ],
      ),
      body: QuestraScreenSurface(
        child: QuestraResponsiveListView(
          maxContentWidth: 720,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            QuestraCard(
              key: const ValueKey('profile-account-card'),
              palette: QuestraSurfacePalette.dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ProfileIcon(
                        icon: Icons.person_outline_rounded,
                        semanticLabel: 'アカウント',
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'アカウント',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: QuestraSurfacePalette.dark.action,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              profile?.nickname ?? 'ゲスト',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color:
                                        QuestraSurfacePalette.dark.foreground,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              profile?.email ?? 'ログインしていません',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color:
                                        QuestraSurfacePalette.dark.foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    profile == null ? 'この端末だけのゲスト航路です' : 'ログイン中の航路です',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: QuestraSurfacePalette.dark.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ProfileStatusBadge(
                    completed: profile?.onboardingCompleted == true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: profile == null
                        ? FilledButton.icon(
                            onPressed: () => context.go(AppRoutes.login),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('ログイン'),
                          )
                        : OutlinedButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .logout();
                              if (context.mounted) {
                                context.go(AppRoutes.login);
                              }
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('ログアウト'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ArcBondCard(bond: bond, profileAvailable: profile != null),
            const SizedBox(height: 16),
            _NavigatorRankCard(rank: navigatorRank, stardust: stardust),
            const SizedBox(height: 16),
            QuestraCard(
              key: const ValueKey('profile-journey-card'),
              palette: QuestraSurfacePalette.dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '旅の現在地',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: QuestraSurfacePalette.dark.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ProfileMetric(
                        label: '進行中のQuest',
                        value: activeQuestCount.toString(),
                      ),
                      _ProfileMetric(
                        label: '未完了のMission',
                        value: openMissionCount.toString(),
                      ),
                      _ProfileMetric(
                        label: 'Trail',
                        value: trails.length.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile == null
                        ? 'ログインすると、この航路を別の端末でも続けられます。'
                        : 'Quest、Mission、Task、Trail、Arc Memoryは、このプロフィールに紐づいて保存されます。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: QuestraSurfacePalette.dark.muted,
                    ),
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

class _NavigatorRankCard extends StatelessWidget {
  const _NavigatorRankCard({required this.rank, required this.stardust});

  final NavigatorRankState rank;
  final StardustState stardust;

  @override
  Widget build(BuildContext context) {
    const palette = QuestraSurfacePalette.dark;
    return QuestraCard(
      key: const ValueKey('profile-rank-card'),
      palette: QuestraSurfacePalette.dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.explore_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stardust / Navigator Rank',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rank.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            rank.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stardust.balance} Stardust',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: QuestraColors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rank.progressToNext,
              minHeight: 10,
              backgroundColor: palette.foreground.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            rank.isMaxRank
                ? '最高ランクに到達しています'
                : '次のランクまで ${rank.remainingToNext} Stardust',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ArcBondCard extends StatelessWidget {
  const _ArcBondCard({required this.bond, required this.profileAvailable});

  final ArcBondState bond;
  final bool profileAvailable;

  @override
  Widget build(BuildContext context) {
    const palette = QuestraSurfacePalette.dark;
    return QuestraCard(
      key: const ValueKey('profile-bond-card'),
      palette: QuestraSurfacePalette.dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArcWidget(
                emotion: ArcEmotion.support,
                size: 72,
                showSpeechBubble: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ArcとのBond',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      profileAvailable
                          ? bond.description
                          : 'ログインするとArcとの航路をこのプロフィールに保存できます。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  bond.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: palette.foreground),
                ),
              ),
              Text(
                '${bond.score} / 100',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: 'ArcとのBond ${bond.score} / 100',
            value: '${(bond.progress * 100).round()}パーセント',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: bond.progress,
                minHeight: 10,
                backgroundColor: palette.foreground.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  QuestraColors.gold,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'QuestやTrailを重ねると、ArcとのBondが育ちます。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.icon, required this.semanticLabel});

  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.skyBlue.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.skyBlue, size: 28),
      ),
    );
  }
}

class _ProfileStatusBadge extends StatelessWidget {
  const _ProfileStatusBadge({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.auroraTeal : AppColors.warmGold;
    final label = completed ? '初期設定済み' : '初期設定が必要です';
    return Semantics(
      label: label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Row(
          children: [
            Icon(
              completed
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: QuestraSurfacePalette.dark.foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: QuestraSurfacePalette.dark.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: QuestraSurfacePalette.dark.muted,
            ),
          ),
        ],
      ),
    );
  }
}
