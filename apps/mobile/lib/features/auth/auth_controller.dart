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
  AuthState build() => const AuthState();

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
        await _upsertProfile(user.id, email, nickname);
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
        state = state.copyWith(
          profile: UserProfile(
            id: user.id,
            email: user.email ?? email,
            nickname: user.userMetadata?['nickname'] as String? ?? 'Adventurer',
          ),
        );
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

  Future<void> completeOnboarding({required String nickname}) async {
    final profile = state.profile;
    if (profile == null) {
      return;
    }

    final updated = profile.copyWith(
      nickname: nickname,
      onboardingCompleted: true,
    );
    state = state.copyWith(profile: updated);

    if (SupabaseConfig.isConfigured) {
      await _upsertProfile(updated.id, updated.email, updated.nickname);
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
    String nickname,
  ) async {
    await Supabase.instance.client.from('user_profiles').upsert({
      'id': userId,
      'nickname': nickname,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
