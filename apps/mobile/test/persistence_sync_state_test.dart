import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/persistence/persistence_sync_state.dart';

void main() {
  test('tracks persistence sync lifecycle messages', () {
    const idle = PersistenceSyncState();
    expect(idle.status, PersistenceSyncStatus.idle);
    expect(idle.isActive, isFalse);

    const loading = PersistenceSyncState(
      status: PersistenceSyncStatus.loading,
      message: '保存しています...',
    );
    expect(loading.isActive, isTrue);
    expect(loading.isFailed, isFalse);

    const failed = PersistenceSyncState(
      status: PersistenceSyncStatus.failed,
      message: '保存に失敗しました。',
    );
    expect(failed.isActive, isTrue);
    expect(failed.isFailed, isTrue);
  });
}
