import 'package:flutter/foundation.dart';

enum PersistenceSource { supabase, localDevelopment, unavailable }

abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _environment = String.fromEnvironment('APP_ENVIRONMENT');
  static const _mockPersistenceRequested = bool.fromEnvironment(
    'ALLOW_MOCK_PERSISTENCE',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static bool get isProduction =>
      resolveProduction(environment: _environment, isReleaseMode: kReleaseMode);

  static bool get localPersistenceAllowed => resolveLocalPersistenceAllowed(
    environment: _environment,
    mockPersistenceRequested: _mockPersistenceRequested,
    isReleaseMode: kReleaseMode,
  );

  static bool get persistenceAvailable =>
      isConfigured || localPersistenceAllowed;

  static PersistenceSource get persistenceSource {
    if (isConfigured) return PersistenceSource.supabase;
    if (localPersistenceAllowed) return PersistenceSource.localDevelopment;
    return PersistenceSource.unavailable;
  }

  @visibleForTesting
  static bool resolveProduction({
    required String environment,
    required bool isReleaseMode,
  }) {
    switch (environment.trim().toLowerCase()) {
      case 'development':
      case 'test':
        return false;
      case 'production':
        return true;
      case '':
        return isReleaseMode;
      default:
        return true;
    }
  }

  @visibleForTesting
  static bool resolveLocalPersistenceAllowed({
    required String environment,
    required bool mockPersistenceRequested,
    required bool isReleaseMode,
  }) {
    if (resolveProduction(
      environment: environment,
      isReleaseMode: isReleaseMode,
    )) {
      return false;
    }
    if (isReleaseMode) return mockPersistenceRequested;
    return true;
  }
}
