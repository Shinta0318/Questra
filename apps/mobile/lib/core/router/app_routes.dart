abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const quest = '/quest';
  static const mission = '/mission';
  static const task = '/task';
  static String missionDetail(String questId, String missionId) =>
      '/quest/$questId/mission/$missionId';
  static String questRoute(String questId) => '/quest/$questId/route';
  static String taskDetail(String questId, String missionId, String taskId) =>
      '/quest/$questId/mission/$missionId/task/$taskId';
  static String missionSupport(String questId, String missionId) =>
      '/quest/$questId/mission/$missionId/support';
  static const trail = '/trail';
  static String trailForTask({
    required String questId,
    required String questTitle,
    required String missionId,
    required String missionTitle,
    required String taskId,
    required String taskTitle,
  }) => Uri(
    path: trail,
    queryParameters: {
      'questId': questId,
      'questTitle': questTitle,
      'missionId': missionId,
      'missionTitle': missionTitle,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'create': '1',
    },
  ).toString();
  static const arc = '/arc';
  static String arcForMission({
    required String questId,
    required String missionId,
    required String prompt,
    required String returnTo,
  }) => Uri(
    path: arc,
    queryParameters: {
      'questId': questId,
      'missionId': missionId,
      'prompt': prompt,
      'returnTo': returnTo,
    },
  ).toString();
  static const guild = '/guild';
  static const profile = '/profile';
  static const settings = '/settings';
  static const dataRights = '/settings/data-rights';
  static const feedback = '/feedback';
}
