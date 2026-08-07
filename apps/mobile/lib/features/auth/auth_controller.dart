import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthException, Supabase, UserAttributes;
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import 'auth_redirects.dart';
import 'auth_state.dart';

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
            }
          });
      ref.onDispose(() => _authSubscription?.cancel());
      unawaited(Future<void>.microtask(restoreSession));
      return const AuthState(isLoading: true);
    }
    return const AuthState();
  }

  Future<void> restoreSession() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

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
    );
    state = state.copyWith(profile: profile, isLoading: false);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
    String? loginId,
  }) async {
    final normalizedLoginId = (loginId?.trim().isNotEmpty ?? false)
        ? loginId!.trim().toLowerCase()
        : email.trim().toLowerCase();
    await _runAuthAction(() async {
      if (SupabaseConfig.isConfigured) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'nickname': nickname, 'login_id': normalizedLoginId},
        );
        final user = response.user;
        if (user == null) {
          throw const AuthException('アカウント作成に失敗しました。');
        }
        if (response.session != null) {
          await Supabase.instance.client.auth.signOut();
        }
        state = state.copyWith(
          clearProfile: true,
          registrationCompleted: true,
          passwordResetCompleted: false,
        );
        return;
      }

      _localAccount = _LocalAccount(
        email: email,
        loginId: normalizedLoginId,
        password: password,
        nickname: nickname,
      );
      state = state.copyWith(
        clearProfile: true,
        registrationCompleted: true,
        passwordResetCompleted: false,
      );
    });
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    await _runAuthAction(() async {
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
          } catch (_) {
            throw const AuthException('ログインに失敗しました。');
          }
        })();
        final payload = Map<String, dynamic>.from(functionResponse.data as Map);
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
        );
        state = state.copyWith(
          profile: profile,
          registrationCompleted: false,
          passwordResetCompleted: false,
          isPasswordRecovery: false,
        );
        return;
      }

      final localAccount = _localAccount;
      if (localAccount != null &&
          identifier.trim().toLowerCase() != localAccount.loginId &&
          identifier.trim().toLowerCase() != localAccount.email.toLowerCase()) {
        throw const AuthException('ログインIDまたはパスワードを確認してください。');
      }
      if (localAccount != null && password != localAccount.password) {
        throw const AuthException('ログインIDまたはパスワードを確認してください。');
      }
      state = state.copyWith(
        profile: UserProfile(
          id: _uuid.v4(),
          email: localAccount?.email ?? identifier,
          loginId: localAccount?.loginId,
          nickname: localAccount?.nickname ?? identifier.split('@').first,
        ),
        registrationCompleted: false,
        passwordResetCompleted: false,
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
        await Supabase.instance.client.auth.resetPasswordForEmail(
          email.trim(),
          redirectTo: AuthRedirects.passwordRecovery,
        );
      }
      state = state.copyWith(
        passwordResetRequested: true,
        passwordResetCompleted: false,
      );
    });
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
        await Supabase.instance.client.rpc('clear_my_login_lock');
        await Supabase.instance.client.auth.signOut();
      } else if (_localAccount != null) {
        _localAccount = _localAccount!.copyWith(password: newPassword);
      }

      state = state.copyWith(
        clearProfile: true,
        isPasswordRecovery: false,
        passwordResetRequested: false,
        passwordResetCompleted: true,
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

  Future<void> addStardust({
    required int amount,
    required String reason,
  }) async {
    final profile = state.profile;
    if (profile == null || amount <= 0) {
      return;
    }

    final nextBalance = profile.stardustBalance + amount;
    final updated = profile.copyWith(stardustBalance: nextBalance);
    state = state.copyWith(profile: updated);

    if (!SupabaseConfig.isConfigured) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'stardust_balance': nextBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profile.id);
    } catch (_) {
      state = state.copyWith(profile: profile);
    }
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isLoading: false);
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthMessage(error.message),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '認証処理を完了できませんでした。通信状態を確認して、もう一度お試しください。',
      );
    }
  }

  String _friendlyAuthMessage(String rawMessage) {
    final message = rawMessage.toLowerCase();
    if (message.contains('rate') ||
        message.contains('too many') ||
        message.contains('60 seconds')) {
      return '操作が続いたため一時停止しています。少し待ってからお試しください。';
    }
    if (message.contains('weak') ||
        message.contains('password') ||
        rawMessage.contains('パスワード')) {
      return 'パスワードは8文字以上で、英字と数字を含めてください。';
    }
    if (message.contains('session') || message.contains('recovery')) {
      return '再設定リンクが無効または期限切れです。もう一度メールを送信してください。';
    }
    if (message.contains('signup') ||
        message.contains('already') ||
        message.contains('database')) {
      return 'アカウントを作成できませんでした。入力内容を確認するか、別のログインIDをお試しください。';
    }
    return 'ログインIDまたはパスワードを確認してください。10回連続で失敗すると30分間ログインできません。';
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
    String? fallbackLoginId,
  ) async {
    final row = await _loadProfileRow(userId);

    if (row == null) {
      return UserProfile(
        id: userId,
        email: email,
        nickname: fallbackNickname ?? 'キャプテン',
        loginId: fallbackLoginId,
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
}

class _LocalAccount {
  const _LocalAccount({
    required this.email,
    required this.loginId,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String loginId;
  final String password;
  final String nickname;

  _LocalAccount copyWith({String? password}) => _LocalAccount(
    email: email,
    loginId: loginId,
    password: password ?? this.password,
    nickname: nickname,
  );
}
