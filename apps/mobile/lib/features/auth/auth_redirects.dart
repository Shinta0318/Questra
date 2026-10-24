import 'package:flutter/foundation.dart';

class SignupConfirmationLink {
  const SignupConfirmationLink({
    this.tokenHash,
    this.accessToken,
    this.refreshToken,
    this.hasLegacyAuthResponse = false,
    this.hasError = false,
  });

  final String? tokenHash;
  final String? accessToken;
  final String? refreshToken;
  final bool hasLegacyAuthResponse;
  final bool hasError;

  bool get hasImplicitSession => accessToken != null && refreshToken != null;
}

class PasswordRecoveryLink {
  const PasswordRecoveryLink({
    this.accessToken,
    this.refreshToken,
    this.hasError = false,
  });

  final String? accessToken;
  final String? refreshToken;
  final bool hasError;

  bool get hasImplicitSession => accessToken != null && refreshToken != null;
}

abstract final class AuthRedirects {
  static const nativeAuthCallback = 'com.questra.questra://login-callback';
  static const nativeSignupConfirmation =
      '$nativeAuthCallback/confirm?auth_callback=signup';
  static const nativePasswordRecovery = nativeAuthCallback;

  static String webSignupConfirmation(Uri base) =>
      '${base.origin}/?auth_callback=signup';

  static String webPasswordRecovery(Uri base) =>
      '${base.origin}/?auth_callback=recovery';

  static String get signupConfirmation {
    if (!kIsWeb) return nativeSignupConfirmation;
    return webSignupConfirmation(Uri.base);
  }

  static bool isSignupConfirmationReturn(Uri uri) {
    if (uri.scheme == 'com.questra.questra') {
      return uri.host == 'login-callback' && uri.path == '/confirm';
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    if ((uri.path.isEmpty || uri.path == '/') &&
        uri.queryParameters['auth_callback'] == 'signup') {
      return true;
    }
    final route = _fragmentRoute(uri);
    return route == '/email-confirmation-return' ||
        (route == '/login' && _hasAuthResponse(uri));
  }

  static SignupConfirmationLink? signupConfirmationLink(Uri uri) {
    if (!isSignupConfirmationReturn(uri)) return null;
    final fragmentParameters = _fragmentParameters(uri);
    final tokenHash =
        fragmentParameters['token_hash'] ?? uri.queryParameters['token_hash'];
    final hasToken =
        fragmentParameters.containsKey('token_hash') ||
        uri.queryParameters.containsKey('token_hash');
    final type = fragmentParameters['type'] ?? uri.queryParameters['type'];
    final validToken =
        tokenHash != null && tokenHash.isNotEmpty && type == 'email';
    final accessToken = fragmentParameters['access_token'];
    final refreshToken = fragmentParameters['refresh_token'];
    final hasSessionToken = accessToken != null || refreshToken != null;
    final validSession =
        accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty &&
        (type == null || type == 'signup' || type == 'email');
    return SignupConfirmationLink(
      tokenHash: validToken ? tokenHash : null,
      accessToken: validSession ? accessToken : null,
      refreshToken: validSession ? refreshToken : null,
      hasLegacyAuthResponse:
          !hasToken &&
          !hasSessionToken &&
          !hasSignupError(uri) &&
          (uri.queryParameters.containsKey('code') ||
              fragmentParameters.containsKey('code')),
      hasError:
          (hasToken && !validToken) ||
          (hasSessionToken && !validSession) ||
          hasSignupError(uri),
    );
  }

  static PasswordRecoveryLink? passwordRecoveryLink(Uri uri) {
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.queryParameters['auth_callback'] != 'recovery') {
      return null;
    }
    final parameters = _fragmentParameters(uri);
    final accessToken = parameters['access_token'];
    final refreshToken = parameters['refresh_token'];
    final hasToken = accessToken != null || refreshToken != null;
    final validSession =
        accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty &&
        parameters['type'] == 'recovery';
    return PasswordRecoveryLink(
      accessToken: validSession ? accessToken : null,
      refreshToken: validSession ? refreshToken : null,
      hasError:
          !validSession ||
          !hasToken ||
          uri.queryParameters.containsKey('error') ||
          uri.queryParameters.containsKey('error_code') ||
          parameters.containsKey('error') ||
          parameters.containsKey('error_code'),
    );
  }

  static bool hasSignupError(Uri uri) {
    final parameters = _fragmentParameters(uri);
    return uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_code') ||
        parameters.containsKey('error') ||
        parameters.containsKey('error_code');
  }

  static bool shouldExchangeSession(Uri uri) {
    final signup = signupConfirmationLink(uri);
    if (signup != null) return signup.hasLegacyAuthResponse;
    if (uri.scheme == 'com.questra.questra') {
      return uri.host == 'login-callback' &&
          (uri.path.isEmpty || uri.path == '/') &&
          _hasAuthResponse(uri);
    }
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        _fragmentRoute(uri) == '/reset-password' &&
        _hasAuthResponse(uri);
  }

  static String cleanedWebConfirmationUrl(Uri uri) {
    return '${uri.origin}/#/email-confirmation-return';
  }

  static String cleanedWebPasswordRecoveryUrl(Uri uri) =>
      '${uri.origin}/#/reset-password';

  static String _fragmentRoute(Uri uri) =>
      uri.fragment.split(RegExp(r'[?#]')).first;

  static Map<String, String> _fragmentParameters(Uri uri) {
    final fragment = uri.fragment;
    final separator = fragment.indexOf(RegExp(r'[?#]'));
    if (separator < 0) {
      return fragment.contains('=') ? Uri.splitQueryString(fragment) : const {};
    }
    return Uri.splitQueryString(fragment.substring(separator + 1));
  }

  static bool _hasAuthResponse(Uri uri) {
    const keys = {
      'access_token',
      'code',
      'error',
      'error_code',
      'error_description',
    };
    final fragmentParameters = _fragmentParameters(uri);
    return keys.any(
      (key) =>
          uri.queryParameters.containsKey(key) ||
          fragmentParameters.containsKey(key),
    );
  }

  static String get passwordRecovery {
    if (!kIsWeb) return nativePasswordRecovery;
    return webPasswordRecovery(Uri.base);
  }
}
