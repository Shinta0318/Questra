import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/arc/arc_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/feedback/beta_feedback_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/mission/mission_detail_screen.dart';
import '../../features/mission/mission_screen.dart';
import '../../features/mission_support/mission_support_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/quest/quest_detail_screen.dart';
import '../../features/quest/quest_form_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/quest/quest_screen.dart';
import '../../features/quest/quest_route_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/trust/data_rights_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/trail/trail_screen.dart';
import '../../features/trail/trail_model.dart';
import '../../features/task/task_detail_screen.dart';
import '../../features/task/task_screen.dart';
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
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
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
        path: AppRoutes.dataRights,
        builder: (context, state) => const DataRightsScreen(),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (context, state) => const BetaFeedbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.guild,
        builder: (context, state) => const QuestraComingSoonScreen(
          featureName: 'Guild',
          message: '近いQuestを持つ仲間と、安心してつながれる航路を準備しています。',
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
                        path: 'route',
                        builder: (context, state) => QuestRouteScreen(
                          questId: state.pathParameters['questId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => QuestFormScreen(
                          questId: state.pathParameters['questId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'mission/:missionId',
                        builder: (context, state) => MissionDetailScreen(
                          missionId: state.pathParameters['missionId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'task/:taskId',
                            builder: (context, state) => TaskDetailScreen(
                              taskId: state.pathParameters['taskId']!,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'mission/:missionId/support',
                        builder: (context, state) => MissionSupportScreen(
                          missionId: state.pathParameters['missionId']!,
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
              GoRoute(
                path: AppRoutes.task,
                builder: (context, state) => const TaskScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.arc,
                builder: (context, state) => ArcScreen(
                  initialPrompt: state.uri.queryParameters['prompt'],
                  focusQuestId: state.uri.queryParameters['questId'],
                  focusMissionId: state.uri.queryParameters['missionId'],
                  returnLocation: state.uri.queryParameters['returnTo'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.trail,
                builder: (context, state) {
                  final query = state.uri.queryParameters;
                  final questId = query['questId'];
                  final questTitle = query['questTitle'];
                  final missionId = query['missionId'];
                  final missionTitle = query['missionTitle'];
                  final taskId = query['taskId'];
                  final taskTitle = query['taskTitle'];
                  final hasTaskParent = [
                    questId,
                    questTitle,
                    missionId,
                    missionTitle,
                    taskId,
                    taskTitle,
                  ].every((value) => value != null && value.trim().isNotEmpty);
                  return TrailScreen(
                    initialParent: hasTaskParent
                        ? TrailParentContext(
                            questId: questId!,
                            questTitle: questTitle!,
                            missionId: missionId!,
                            missionTitle: missionTitle!,
                            taskId: taskId!,
                            taskTitle: taskTitle!,
                          )
                        : null,
                    openComposer: query['create'] == '1' && hasTaskParent,
                  );
                },
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
