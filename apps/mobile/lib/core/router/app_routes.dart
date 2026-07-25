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
  static String missionSupport(String questId, String missionId) =>
      '/quest/$questId/mission/$missionId/support';
  static const trail = '/trail';
  static const arc = '/arc';
  static const guild = '/guild';
  static const profile = '/profile';
  static const settings = '/settings';
  static const feedback = '/feedback';
}
