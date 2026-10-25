import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, AuthFlowType, SupabaseClient;

SupabaseClient createPasswordRecoveryEmailClient(
  String url,
  String publishableKey,
) => SupabaseClient(
  url,
  publishableKey,
  authOptions: const AuthClientOptions(
    authFlowType: AuthFlowType.implicit,
    autoRefreshToken: false,
  ),
);

Future<bool> completeImplicitPasswordRecovery(
  SupabaseClient client, {
  required String accessToken,
  required String refreshToken,
}) async {
  try {
    final response = await client.auth.setSession(
      refreshToken,
      accessToken: accessToken,
    );
    if (response.session == null || response.user == null) {
      await client.auth.signOut();
      return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

class PasswordResetFinalization {
  const PasswordResetFinalization({
    required this.loginLockCleared,
    required this.signedOut,
  });

  final bool loginLockCleared;
  final bool signedOut;
}

Future<PasswordResetFinalization> finalizePasswordReset({
  required Future<void> Function() clearLoginLock,
  required Future<void> Function() signOut,
}) async {
  var loginLockCleared = true;
  try {
    await clearLoginLock();
  } catch (_) {
    loginLockCleared = false;
  }

  var signedOut = true;
  try {
    await signOut();
  } catch (_) {
    signedOut = false;
  }
  return PasswordResetFinalization(
    loginLockCleared: loginLockCleared,
    signedOut: signedOut,
  );
}
