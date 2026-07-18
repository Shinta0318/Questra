import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/arc/arc_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/feedback/beta_feedback_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/mission/mission_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/quest/quest_detail_screen.dart';
import '../../features/quest/quest_form_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/quest/quest_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../widgets/layout/questra_coming_soon_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (context, state) => const BetaFeedbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.trail,
        builder: (context, state) => const QuestraComingSoonScreen(
          featureName: 'Trail',
          message: '挑戦の軌跡を、もっと美しく残せる場所を整えています。もう少しだけ待っていてね。',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.quest,
                builder: (context, state) => const QuestScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const QuestFormScreen(),
                  ),
                  GoRoute(
                    path: ':questId',
                    builder: (context, state) => QuestDetailScreen(
                      questId: state.pathParameters['questId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => QuestFormScreen(
                          questId: state.pathParameters['questId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.mission,
                builder: (context, state) => const MissionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.arc,
                builder: (context, state) => const ArcScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.guild,
                builder: (context, state) => const QuestraComingSoonScreen(
                  featureName: 'Guild',
                  message: '近いQuestを持つ仲間と、安心してつながれる航路を準備しています。',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
