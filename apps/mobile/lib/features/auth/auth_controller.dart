import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthChangeEvent,
        AuthException,
        AuthResponse,
        FunctionException,
        OtpType,
        Supabase,
        UserAttributes;
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../arc/stardust_service.dart';
import '../trust/legal_policy.dart';
import 'auth_redirects.dart';
import 'auth_error_feedback.dart';
import 'auth_state.dart';
import 'password_recovery_service.dart';
import 'signup_confirmation_service.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  final _uuid = const Uuid();
  StreamSubscription? _authSubscription;
  _LocalAccount? _localAccount;

  @override
  AuthState build() {
    if (SupabaseConfig.isConfigured) {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((event) {
            if (event.event == AuthChangeEvent.passwordRecovery) {
              state = state.copyWith(
                isPasswordRecovery: true,
                isLoading: false,
                clearError: true,
              );
            } else if (event.event == AuthChangeEvent.signedOut) {
              state = state.copyWith(
                clearProfile: true,
                isPasswordRecovery: false,
                isLoading: false,
              );
            }
          });
      ref.onDispose(() => _authSubscription?.cancel());
      unawaited(Future<void>.microtask(restoreSession));
      return const AuthState(isLoading: true);
    }
    if (SupabaseConfig.autoEnterLocalMock) {
      return AuthState(profile: _localMockProfile());
    }
    return const AuthState();
  }

  UserProfile _localMockProfile() => UserProfile(
    id: _uuid.v4(),
    email: 'preview@local.questra',
    loginId: 'preview',
    nickname: 'キャプテン',
    onboardingCompleted: true,
    hasSeenOnboardingTour: true,
    legalAcceptanceCurrent: true,
  );

  Future<void> restoreSession() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false, clearProfile: true);
        return;
      }

      final profile = await _loadProfile(
        user.id,
        user.email ?? '',
        user.userMetadata?['nickname'] as String?,
        user.userMetadata?['login_id'] as String?,
        signupMetadata: user.userMetadata,
      );
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (_) {
      state = state.copyWith(
        clearProfile: true,
        isLoading: false,
        errorMessage: 'セッションを確認できませんでした。通信状態を確認して、もう一度お試しください。',
      );
    }
  }

  void setSignupConfirmationStatus(SignupConfirmationStatus status) {
    state = state.copyWith(signupConfirmationStatus: status);
  }

  void activatePasswordRecovery() {
    state = state.copyWith(
      isPasswordRecovery: true,
      isLoading: false,
      clearError: true,
    );
  }

  Future<SignupConfirmationStatus> confirmSignupToken(String tokenHash) async {
    setSignupConfirmationStatus(SignupConfirmationStatus.checking);
    var result = await verifySignupConfirmation(
      Supabase.instance.client,
      tokenHash,
    );
    if (result == SignupConfirmationStatus.verified) {
      await restoreSession();
      if (!state.isAuthenticated) {
        result = SignupConfirmationStatus.unavailable;
      }
    }
    setSignupConfirmationStatus(result);
    return result;
  }

  Future<SignupConfirmationStatus> confirmSignupSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    setSignupConfirmationStatus(SignupConfirmationStatus.checking);
    var result = await completeImplicitSignupConfirmation(
      Supabase.instance.client,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    if (result == SignupConfirmationStatus.verified) {
      await restoreSession();
      if (!state.isAuthenticated) result = SignupConfirmationStatus.unavailable;
    }
    setSignupConfirmationStatus(result);
    return result;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
    String? loginId,
    required LegalAcceptance legalAcceptance,
  }) async {
    final normalizedLoginId = (loginId?.trim().isNotEmpty ?? false)
        ? loginId!.trim().toLowerCase()
        : email.trim().toLowerCase();
    await _runAuthAction(() async {
      if (!legalAcceptance.isCurrent) {
        throw const AuthException('legal_acceptance_required');
      }
      if (SupabaseConfig.isConfigured) {
        final signupClient = createSignupEmailClient(
          SupabaseConfig.url,
          SupabaseConfig.anonKey,
        );
        late final AuthResponse response;
        try {
          Map<String, dynamic>? activePolicy;
          try {
            activePolicy = await signupClient
                .from('legal_release_policies')
                .select(
                  'active,minimum_age,eligibility_version,terms_version,privacy_version,ai_disclosure_version',
                )
                .eq('region_code', QuestraLegalPolicy.regionCode)
                .eq('active', true)
                .maybeSingle();
          } catch (_) {
            throw const AuthException(
              'signup_unavailable',
              code: 'signup_unavailable',
            );
          }
          switch (QuestraLegalPolicy.activePolicyState(activePolicy)) {
            case ActiveLegalPolicyState.current:
              break;
            case ActiveLegalPolicyState.unavailable:
              throw const AuthException(
                'signup_unavailable',
                code: 'signup_unavailable',
              );
            case ActiveLegalPolicyState.updateRequired:
              throw const AuthException(
                'app_update_required',
                code: 'app_update_required',
              );
          }
          response = await signupClient.auth.signUp(
            email: email,
            password: password,
            emailRedirectTo: AuthRedirects.signupConfirmation,
            data: {
              'nickname': nickname,
              'login_id': normalizedLoginId,
              ...legalAcceptance.toAuthMetadata(),
            },
          );
          if (response.session != null) await signupClient.auth.signOut();
        } finally {
          await signupClient.dispose();
        }
        final user = response.user;
        if (user == null) {
          throw const AuthException('アカウント作成に失敗しました。');
        }
        state = state.copyWith(
          clearProfile: true,
          registrationCompleted: true,
          passwordResetCompleted: false,
        );
        return;
      }

      _ensureLocalPersistenceAllowed();

      _localAccount = _LocalAccount(
        email: email,
        loginId: normalizedLoginId,
        password: password,
        nickname: nickname,
        legalAcceptanceCurrent: true,
      );
      state = state.copyWith(
        clearProfile: true,
        registrationCompleted: true,
        passwordResetCompleted: false,
      );
    }, errorContext: AuthErrorContext.signup);
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    await _runAuthAction(
      () async {
        if (SupabaseConfig.isConfigured) {
          final functionResponse = await (() async {
            try {
              return await Supabase.instance.client.functions.invoke(
                'auth-login',
                body: {
                  'identifier': identifier.trim().toLowerCase(),
                  'password': password,
                },
              );
            } on FunctionException catch (error) {
              throw loginFunctionFailure(error);
            } catch (_) {
              throw const AuthException(
                'login_unavailable',
                code: 'login_unavailable',
              );
            }
          })();
          final payload = Map<String, dynamic>.from(
            functionResponse.data as Map,
          );
          final accessToken = payload['access_token'] as String?;
          final refreshToken = payload['refresh_token'] as String?;
          if (accessToken == null || refreshToken == null) {
            throw const AuthException('ログインに失敗しました。');
          }
          final response = await Supabase.instance.client.auth.setSession(
            refreshToken,
            accessToken: accessToken,
          );
          final user = response.user;
          if (user == null) {
            throw const AuthException('ログインに失敗しました。');
          }
          final profile = await _loadProfile(
            user.id,
            user.email ?? '',
            user.userMetadata?['nickname'] as String?,
            user.userMetadata?['login_id'] as String?,
            signupMetadata: user.userMetadata,
          );
          state = state.copyWith(
            profile: profile,
            registrationCompleted: false,
            passwordResetCompleted: false,
            passwordResetSignOutPending: false,
            passwordResetLockClearFailed: false,
            isPasswordRecovery: false,
          );
          return;
        }

        _ensureLocalPersistenceAllowed();

        final localAccount = _localAccount;
        if (localAccount == null) {
          throw const AuthException(
            'local_mock_account_missing',
            code: 'local_mock_account_missing',
          );
        }
        final normalizedIdentifier = identifier.trim().toLowerCase();
        if ((normalizedIdentifier != localAccount.loginId &&
                normalizedIdentifier != localAccount.email.toLowerCase()) ||
            password != localAccount.password) {
          throw const AuthException(
            'local_mock_invalid_credentials',
            code: 'local_mock_invalid_credentials',
          );
        }
        state = state.copyWith(
          profile: UserProfile(
            id: _uuid.v4(),
            email: localAccount.email,
            loginId: localAccount.loginId,
            nickname: localAccount.nickname,
            legalAcceptanceCurrent: localAccount.legalAcceptanceCurrent,
          ),
          registrationCompleted: false,
          passwordResetCompleted: false,
        );
      },
      errorContext: SupabaseConfig.isConfigured
          ? AuthErrorContext.login
          : AuthErrorContext.localPreviewLogin,
    );
  }

  Future<void> enterLocalMockPreview() async {
    await _runAuthAction(() async {
      _ensureLocalPersistenceAllowed();
      if (SupabaseConfig.isConfigured) {
        throw const AuthException('Local mock preview is unavailable.');
      }
      state = state.copyWith(
        profile: _localMockProfile(),
        registrationCompleted: false,
        passwordResetCompleted: false,
        isPasswordRecovery: false,
      );
    });
  }

  Future<void> logout() async {
    await _runAuthAction(() async {
      if (SupabaseConfig.isConfigured) {
        await Supabase.instance.client.auth.signOut();
      }
      state = state.copyWith(clearProfile: true);
    });
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _runAuthAction(() async {
      if (SupabaseConfig.isConfigured) {
        if (kIsWeb) {
          final recoveryClient = createPasswordRecoveryEmailClient(
            SupabaseConfig.url,
            SupabaseConfig.anonKey,
          );
          try {
            await recoveryClient.auth.resetPasswordForEmail(
              email.trim(),
              redirectTo: AuthRedirects.passwordRecovery,
            );
          } finally {
            await recoveryClient.dispose();
          }
        } else {
          await Supabase.instance.client.auth.resetPasswordForEmail(
            email.trim(),
            redirectTo: AuthRedirects.passwordRecovery,
          );
        }
      } else {
        _ensureLocalPersistenceAllowed();
        throw const AuthException(
          'local_mail_unavailable',
          code: 'local_mail_unavailable',
        );
      }
      state = state.copyWith(
        passwordResetRequested: true,
        passwordResetCompleted: false,
      );
    });
  }

  Future<bool> resendSignupConfirmation({required String email}) async {
    await _runAuthAction(() async {
      if (!SupabaseConfig.isConfigured) {
        throw const AuthException('confirmation_unavailable');
      }
      final signupClient = createSignupEmailClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
      );
      try {
        await signupClient.auth.resend(
          type: OtpType.signup,
          email: email.trim(),
          emailRedirectTo: AuthRedirects.signupConfirmation,
        );
      } finally {
        await signupClient.dispose();
      }
    }, errorContext: AuthErrorContext.confirmation);
    return state.errorMessage == null;
  }

  Future<void> completePasswordReset({required String newPassword}) async {
    await _runAuthAction(() async {
      if (SupabaseConfig.isConfigured) {
        final response = await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        if (response.user == null) {
          throw const AuthException('パスワードを更新できませんでした。');
        }
        final finalization = await finalizePasswordReset(
          clearLoginLock: () async {
            await Supabase.instance.client.rpc('clear_my_login_lock');
          },
          signOut: () => Supabase.instance.client.auth.signOut(),
        );
        state = state.copyWith(
          clearProfile: finalization.signedOut,
          isPasswordRecovery: !finalization.signedOut,
          passwordResetRequested: false,
          passwordResetCompleted: true,
          passwordResetSignOutPending: !finalization.signedOut,
          passwordResetLockClearFailed: !finalization.loginLockCleared,
        );
      } else {
        _ensureLocalPersistenceAllowed();
        throw const AuthException(
          'local_mail_unavailable',
          code: 'local_mail_unavailable',
        );
      }
    });
  }

  Future<void> finishPasswordResetSignOut() async {
    if (!state.passwordResetCompleted || !state.passwordResetSignOutPending) {
      return;
    }
    await _runAuthAction(() async {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        throw const AuthException(
          'password_reset_sign_out_failed',
          code: 'password_reset_sign_out_failed',
        );
      }
      state = state.copyWith(
        clearProfile: true,
        isPasswordRecovery: false,
        passwordResetSignOutPending: false,
      );
    });
  }

  void clearAuthNotices() {
    state = state.copyWith(
      registrationCompleted: false,
      passwordResetRequested: false,
      passwordResetCompleted: false,
      clearError: true,
    );
  }

  Future<void> acceptCurrentLegalPolicy(LegalAcceptance acceptance) async {
    final profile = state.profile;
    if (profile == null) return;
    await _runAuthAction(() async {
      if (!acceptance.isCurrent) {
        throw const AuthException('legal_acceptance_required');
      }
      if (SupabaseConfig.isConfigured) {
        await Supabase.instance.client.rpc<Object?>(
          'accept_current_legal_policy',
          params: {
            'p_eligibility_version': acceptance.eligibilityVersion,
            'p_terms_version': acceptance.termsVersion,
            'p_privacy_version': acceptance.privacyVersion,
            'p_ai_disclosure_version': acceptance.aiDisclosureVersion,
            'p_region_code': acceptance.regionCode,
            'p_minimum_age_confirmed': acceptance.minimumAgeConfirmed,
            'p_accepted_at_client': acceptance.acceptedAt
                .toUtc()
                .toIso8601String(),
          },
        );
      } else {
        _ensureLocalPersistenceAllowed();
      }
      if (SupabaseConfig.isConfigured &&
          !(await _currentLegalAcceptance(profile.id)).current) {
        throw const AuthException('legal_acceptance_not_recorded');
      }
      state = state.copyWith(
        profile: profile.copyWith(
          legalAcceptanceCurrent: true,
          legalAcceptanceCheckAvailable: true,
          legalPolicyUpdateRequired: false,
        ),
      );
    }, errorContext: AuthErrorContext.legalConsent);
  }

  Future<void> completeOnboarding({
    required String nickname,
    String arcName = 'Arc',
    QuestInterest questInterest = QuestInterest.adventure,
    SignalFrequency signalFrequency = SignalFrequency.balanced,
  }) async {
    final profile = state.profile;
    if (profile == null) {
      return;
    }

    final updated = profile.copyWith(
      nickname: nickname,
      arcName: arcName.trim().isEmpty ? 'Arc' : arcName.trim(),
      questInterest: questInterest,
      signalFrequency: signalFrequency,
      onboardingCompleted: true,
    );
    state = state.copyWith(profile: updated, isLoading: true, clearError: true);

    try {
      if (SupabaseConfig.isConfigured) {
        await _upsertProfile(
          updated.id,
          updated.email,
          updated.nickname,
          arcName: updated.arcName,
          questInterest: updated.questInterest,
          signalFrequency: updated.signalFrequency,
          onboardingCompleted: updated.onboardingCompleted,
          hasSeenOnboardingTour: updated.hasSeenOnboardingTour,
        );
      }
      state = state.copyWith(profile: updated, isLoading: false);
    } catch (error) {
      state = state.copyWith(
        profile: updated,
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> markOnboardingTourSeen({bool seen = true}) async {
    final profile = state.profile;
    if (profile == null) {
      return;
    }

    final updated = profile.copyWith(hasSeenOnboardingTour: seen);
    state = state.copyWith(profile: updated, clearError: true);

    if (!SupabaseConfig.isConfigured) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'has_seen_onboarding_tour': seen,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', updated.id);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> addBondScore({
    required int delta,
    required String reason,
  }) async {
    final profile = state.profile;
    if (profile == null || delta <= 0) {
      return;
    }

    final nextScore = (profile.bondScore + delta).clamp(0, 100);
    final updated = profile.copyWith(bondScore: nextScore);
    state = state.copyWith(profile: updated);

    if (!SupabaseConfig.isConfigured) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'bond_score': nextScore,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profile.id);
    } catch (_) {
      state = state.copyWith(profile: profile);
    }
  }

  Future<void> awardStardust({
    required StardustEvent event,
    required String sourceId,
  }) async {
    final profile = state.profile;
    if (profile == null || !SupabaseConfig.isConfigured) {
      return;
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'award_stardust',
        params: {'p_event_type': event.storageKey, 'p_source_id': sourceId},
      );
      if (state.profile?.id != profile.id || response is! Map) return;
      final balance = (response['stardust_balance'] as num?)?.toInt();
      final rank = response['navigator_rank'] as String?;
      if (balance == null || rank == null) return;
      state = state.copyWith(
        profile: state.profile!.copyWith(
          stardustBalance: balance,
          navigatorRank: rank,
        ),
      );
    } catch (_) {
      // Progress rewards are server-authoritative and can be retried safely.
    }
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    AuthErrorContext? errorContext,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isLoading: false);
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyAuthError(error, errorContext),
        errorContext: errorContext,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorContext == AuthErrorContext.legalConsent
            ? '利用条件への同意を保存できませんでした。しばらくしてから再試行してください。'
            : '認証処理を完了できませんでした。通信状態を確認して、もう一度お試しください。',
        errorContext: errorContext,
      );
    }
  }

  void _ensureLocalPersistenceAllowed() {
    if (!SupabaseConfig.localPersistenceAllowed) {
      throw const AuthException('Supabaseの接続設定が必要です。');
    }
  }

  Future<void> _upsertProfile(
    String userId,
    String email,
    String nickname, {
    required String arcName,
    required QuestInterest questInterest,
    required SignalFrequency signalFrequency,
    required bool onboardingCompleted,
    bool hasSeenOnboardingTour = false,
  }) async {
    await Supabase.instance.client.from('user_profiles').upsert({
      'id': userId,
      'nickname': nickname,
      'arc_name': arcName,
      'quest_interest': questInterest.storageKey,
      'signal_frequency': signalFrequency.storageKey,
      'onboarding_completed': onboardingCompleted,
      'has_seen_onboarding_tour': hasSeenOnboardingTour,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<UserProfile> _loadProfile(
    String userId,
    String email,
    String? fallbackNickname,
    String? fallbackLoginId, {
    Map<String, dynamic>? signupMetadata,
  }) async {
    final row = await _loadProfileRow(userId);
    final legalAcceptance = await _currentLegalAcceptance(userId);
    final priorSignupConsentClaimed = QuestraLegalPolicy.matchesSignupMetadata(
      signupMetadata,
    );

    if (row == null) {
      return UserProfile(
        id: userId,
        email: email,
        nickname: fallbackNickname ?? 'キャプテン',
        loginId: fallbackLoginId,
        legalAcceptanceCurrent: legalAcceptance.current,
        legalAcceptanceCheckAvailable: legalAcceptance.available,
        legalPolicyUpdateRequired: legalAcceptance.updateRequired,
        priorSignupConsentClaimed: priorSignupConsentClaimed,
      );
    }

    return UserProfile(
      id: row['id'] as String,
      email: email,
      nickname: row['nickname'] as String? ?? fallbackNickname ?? 'キャプテン',
      loginId: fallbackLoginId,
      arcName: row['arc_name'] as String? ?? 'Arc',
      questInterest: questInterestFromStorage(row['quest_interest'] as String?),
      signalFrequency: signalFrequencyFromStorage(
        row['signal_frequency'] as String?,
      ),
      onboardingCompleted: row['onboarding_completed'] as bool? ?? false,
      hasSeenOnboardingTour: row['has_seen_onboarding_tour'] as bool? ?? false,
      arcLevel: row['arc_level'] as int? ?? 1,
      bondScore: row['bond_score'] as int? ?? 0,
      stardustBalance: row['stardust_balance'] as int? ?? 0,
      navigatorRank: row['navigator_rank'] as String? ?? 'novice',
      legalAcceptanceCurrent: legalAcceptance.current,
      legalAcceptanceCheckAvailable: legalAcceptance.available,
      legalPolicyUpdateRequired: legalAcceptance.updateRequired,
      priorSignupConsentClaimed: priorSignupConsentClaimed,
    );
  }

  Future<Map<String, dynamic>?> _loadProfileRow(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'id,nickname,arc_name,quest_interest,signal_frequency,onboarding_completed,has_seen_onboarding_tour,arc_level,bond_score,stardust_balance,navigator_rank',
          )
          .eq('id', userId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      final row = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'id,nickname,onboarding_completed,arc_level,bond_score,stardust_balance,navigator_rank',
          )
          .eq('id', userId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    }
  }

  Future<({bool current, bool available, bool updateRequired})>
  _currentLegalAcceptance(String userId) async {
    try {
      final activePolicy = await Supabase.instance.client
          .from('legal_release_policies')
          .select(
            'active,minimum_age,eligibility_version,terms_version,privacy_version,ai_disclosure_version',
          )
          .eq('region_code', QuestraLegalPolicy.regionCode)
          .eq('active', true)
          .maybeSingle();
      switch (QuestraLegalPolicy.activePolicyState(activePolicy)) {
        case ActiveLegalPolicyState.unavailable:
          return (current: false, available: false, updateRequired: false);
        case ActiveLegalPolicyState.updateRequired:
          return (current: false, available: true, updateRequired: true);
        case ActiveLegalPolicyState.current:
          break;
      }
      final row = await Supabase.instance.client
          .from('legal_acceptances')
          .select('id')
          .eq('user_id', userId)
          .eq('eligibility_version', QuestraLegalPolicy.eligibilityVersion)
          .eq('terms_version', QuestraLegalPolicy.termsVersion)
          .eq('privacy_version', QuestraLegalPolicy.privacyVersion)
          .eq('ai_disclosure_version', QuestraLegalPolicy.aiDisclosureVersion)
          .eq('region_code', QuestraLegalPolicy.regionCode)
          .eq('minimum_age_confirmed', true)
          .maybeSingle();
      return (current: row != null, available: true, updateRequired: false);
    } catch (_) {
      return (current: false, available: false, updateRequired: false);
    }
  }
}

class _LocalAccount {
  const _LocalAccount({
    required this.email,
    required this.loginId,
    required this.password,
    required this.nickname,
    required this.legalAcceptanceCurrent,
  });

  final String email;
  final String loginId;
  final String password;
  final String nickname;
  final bool legalAcceptanceCurrent;
}
