import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/persistence/database_write_feedback.dart';
import 'package:questra/core/persistence/persistence_sync_state.dart';
import 'package:questra/features/auth/auth_error_feedback.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/task/task_mutation_state.dart';
import 'package:questra/features/trail/trail_sync_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

void main() {
  PostgrestException databaseError(String code) => PostgrestException(
    message: 'duplicate key value violates unique constraint secret_table_pkey',
    code: code,
    details: 'Key (private_email) already exists.',
    hint: 'private SQL hint',
  );

  test('maps known database constraints without exposing raw SQL details', () {
    final expected = {
      '23505': '重複',
      '23503': '関連するデータ',
      '23502': '必須情報',
      '23514': '登録条件',
      '22001': '登録条件',
      '22P02': '登録条件',
      '42501': '権限',
    };
    for (final entry in expected.entries) {
      final feedback = DatabaseWriteFeedback.from(databaseError(entry.key));
      expect(feedback?.message, contains(entry.value));
      expect(feedback?.message, isNot(contains('secret_table')));
      expect(feedback?.message, isNot(contains('private_email')));
      expect(feedback?.message, isNot(contains('private SQL hint')));
    }
    expect(DatabaseWriteFeedback.from(databaseError('XX000')), isNull);
    expect(DatabaseWriteFeedback.from(StateError('not a DB error')), isNull);
  });

  test('Quest and Mission saves show actionable constraint feedback', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider =
        NotifierProvider<PersistenceSyncController, PersistenceSyncState>(
          PersistenceSyncController.new,
        );
    final sync = container.read(provider.notifier);
    sync.loading('保存中', operation: PersistenceSyncOperation.save);
    sync.failed('Questの保存', databaseError('23505'), retryAvailable: true);
    final result = container.read(provider);
    expect(result.message, contains('重複'));
    expect(result.message, contains('変更内容は保持されています'));
    expect(result.retryAvailable, isFalse);
  });

  test('Trail and Task saves also announce database constraints', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final trailSync = container.read(trailSyncControllerProvider.notifier);
    trailSync.loading('保存中', TrailSyncOperation.save);
    trailSync.failed(databaseError('23503'));
    expect(
      container.read(trailSyncControllerProvider).message,
      contains('関連するデータ'),
    );

    final taskSync = container.read(taskMutationControllerProvider.notifier);
    taskSync.failed(
      const PendingTaskMutation(
        ownerId: 'owner',
        idempotencyKey: 'key',
        desired: [],
        previous: [],
      ),
      databaseError('23502'),
    );
    expect(
      container.read(taskMutationControllerProvider).message,
      contains('必須情報'),
    );
  });

  test(
    'signup handles known Auth codes and ambiguous trigger failures safely',
    () {
      expect(
        friendlyAuthError(
          const AuthException('Email exists', code: 'email_exists'),
          AuthErrorContext.signup,
        ),
        contains('登録済み'),
      );
      final ambiguous = friendlyAuthError(
        const AuthException(
          'Database error saving new user: secret_table_pkey',
          code: 'unexpected_failure',
        ),
        AuthErrorContext.signup,
      );
      expect(ambiguous, contains('可能性'));
      expect(ambiguous, isNot(contains('secret_table')));
      expect(
        friendlyAuthError(
          const AuthException(
            'Invalid login credentials',
            code: 'invalid_credentials',
          ),
          AuthErrorContext.login,
        ),
        isNot(contains('8文字以上')),
      );
    },
  );
}
