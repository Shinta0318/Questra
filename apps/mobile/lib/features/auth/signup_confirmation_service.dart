import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthClientOptions,
        AuthException,
        AuthFlowType,
        OtpType,
        SupabaseClient;

enum SignupConfirmationStatus { idle, checking, verified, invalid, unavailable }

// Only signup emails use implicit flow so the confirmation link can open in a different browser.
SupabaseClient createSignupEmailClient(String url, String publishableKey) =>
    SupabaseClient(
      url,
      publishableKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );

Future<SignupConfirmationStatus> verifySignupConfirmation(
  SupabaseClient client,
  String tokenHash,
) async {
  try {
    final response = await client.auth.verifyOTP(
      type: OtpType.email,
      tokenHash: tokenHash,
    );
    return response.user != null && response.session != null
        ? SignupConfirmationStatus.verified
        : SignupConfirmationStatus.invalid;
  } on AuthException catch (error) {
    const invalidCodes = {
      'otp_expired',
      'invalid_token',
      'token_expired',
      'validation_failed',
    };
    return invalidCodes.contains(error.code)
        ? SignupConfirmationStatus.invalid
        : SignupConfirmationStatus.unavailable;
  } catch (_) {
    return SignupConfirmationStatus.unavailable;
  }
}

Future<SignupConfirmationStatus> completeImplicitSignupConfirmation(
  SupabaseClient client, {
  required String accessToken,
  required String refreshToken,
}) async {
  try {
    final response = await client.auth.setSession(
      refreshToken,
      accessToken: accessToken,
    );
    final user = response.user;
    if (user == null ||
        response.session == null ||
        user.emailConfirmedAt == null) {
      await client.auth.signOut();
      return SignupConfirmationStatus.invalid;
    }
    return SignupConfirmationStatus.verified;
  } on AuthException catch (error) {
    const invalidCodes = {
      'invalid_grant',
      'invalid_token',
      'refresh_token_not_found',
      'token_expired',
    };
    return invalidCodes.contains(error.code)
        ? SignupConfirmationStatus.invalid
        : SignupConfirmationStatus.unavailable;
  } catch (_) {
    return SignupConfirmationStatus.unavailable;
  }
}
