import '../../features/auth/auth_state.dart';
import 'app_routes.dart';

abstract final class AuthRouteGuard {
  static const _publicPaths = <String>{
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
  };

  static String? redirect({
    required AuthState auth,
    required Uri location,
    required bool persistenceAvailable,
  }) {
    final path = location.path;

    if (!persistenceAvailable) {
      return path == AppRoutes.splash ? null : AppRoutes.splash;
    }
    if (auth.isLoading) {
      if (_publicPaths.contains(path)) return null;
      return Uri(
        path: AppRoutes.splash,
        queryParameters: {'continue': location.toString()},
      ).toString();
    }

    if (!auth.isAuthenticated) {
      final continuation = safeContinuation(
        location.queryParameters['continue'],
      );
      if (path == AppRoutes.splash && continuation != null) {
        return _loginLocation(continuation);
      }
      if (_publicPaths.contains(path)) return null;
      return _loginLocation(location.toString());
    }

    if (path == AppRoutes.resetPassword && auth.isPasswordRecovery) {
      return null;
    }

    final legalAcceptanceCurrent = auth.profile?.legalAcceptanceCurrent == true;
    if (!legalAcceptanceCurrent) {
      return path == AppRoutes.legalConsent ? null : AppRoutes.legalConsent;
    }

    final onboardingComplete = auth.profile?.onboardingCompleted == true;
    if (!onboardingComplete) {
      return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    }

    if (path == AppRoutes.onboarding) return AppRoutes.home;
    if (path == AppRoutes.legalConsent) return AppRoutes.home;
    if (_publicPaths.contains(path)) {
      return safeContinuation(location.queryParameters['continue']) ??
          AppRoutes.home;
    }
    return null;
  }

  static String? safeContinuation(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/') ||
        uri.path.startsWith('//') ||
        _publicPaths.contains(uri.path)) {
      return null;
    }
    return uri.toString();
  }

  static String _loginLocation(String continuation) => Uri(
    path: AppRoutes.login,
    queryParameters: {'continue': continuation},
  ).toString();
}
