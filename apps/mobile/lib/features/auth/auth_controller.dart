import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, Supabase;
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import 'auth_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  final _uuid = const Uuid();

  @override
  AuthState build() {
    if (SupabaseConfig.isConfigured) {
      unawaited(restoreSession());
    }
    return const AuthState();
  }

  Future<void> restoreSession() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final profile = await _loadProfile(
      user.id,
      user.email ?? '',
      user.userMetadata?['nickname'] as String?,
    );
    state = state.copyWith(profile: profile, isLoading: false);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    await _runAuthAction(() async {
      if (SupabaseConfig.isConfigured) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'nickname': nickname},
        );
        final user = response.user;
        if (user == null) {
          throw const AuthException('Signup did not return a user.');
        }
        await _upsertProfile(
          user.id,
          email,
          nickname,
          arcName: 'Arc',
          questInterest: QuestInterest.adventure,
          signalFrequency: SignalFrequency.balanced,
          onboardingCompleted: false,
        );
        state = state.copyWith(
          profile: UserProfile(id: user.id, email: email, nickname: nickname),
        );
        return;
      }

      state = state.copyWith(
        profile: UserProfile(id: _uuid.v4(), email: email, nickname: nickname),
      );
    });
  }

  Future<void> login({required String email, required String password}) async {
    await _runAuthAction(() async {
      if (SupabaseConfig.isConfigured) {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = response.user;
        if (user == null) {
          throw const AuthException('Login did not return a user.');
        }
        final profile = await _loadProfile(
          user.id,
          user.email ?? email,
          user.userMetadata?['nickname'] as String?,
        );
        state = state.copyWith(profile: profile);
        return;
      }

      state = state.copyWith(
        profile: UserProfile(
          id: _uuid.v4(),
          email: email,
          nickname: email.split('@').first,
        ),
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
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
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
  }) async {
    await Supabase.instance.client.from('user_profiles').upsert({
      'id': userId,
      'nickname': nickname,
      'arc_name': arcName,
      'quest_interest': questInterest.storageKey,
      'signal_frequency': signalFrequency.storageKey,
      'onboarding_completed': onboardingCompleted,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<UserProfile> _loadProfile(
    String userId,
    String email,
    String? fallbackNickname,
  ) async {
    final row = await _loadProfileRow(userId);

    if (row == null) {
      return UserProfile(
        id: userId,
        email: email,
        nickname: fallbackNickname ?? 'Adventurer',
      );
    }

    return UserProfile(
      id: row['id'] as String,
      email: email,
      nickname: row['nickname'] as String? ?? fallbackNickname ?? 'Adventurer',
      arcName: row['arc_name'] as String? ?? 'Arc',
      questInterest: questInterestFromStorage(row['quest_interest'] as String?),
      signalFrequency: signalFrequencyFromStorage(
        row['signal_frequency'] as String?,
      ),
      onboardingCompleted: row['onboarding_completed'] as bool? ?? false,
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
            'id,nickname,arc_name,quest_interest,signal_frequency,onboarding_completed,arc_level,bond_score,stardust_balance,navigator_rank',
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
