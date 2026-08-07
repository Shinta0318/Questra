import 'package:flutter/foundation.dart';

abstract final class AuthRedirects {
  static const nativePasswordRecovery = 'com.questra.questra://login-callback';

  static String get passwordRecovery {
    if (!kIsWeb) return nativePasswordRecovery;
    return '${Uri.base.origin}/#/reset-password';
  }
}
