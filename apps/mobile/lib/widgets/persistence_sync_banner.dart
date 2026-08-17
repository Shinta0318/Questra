import 'package:flutter/material.dart';

import '../core/persistence/persistence_sync_state.dart';
import 'feedback/questra_notification.dart';

class PersistenceSyncBanner extends StatelessWidget {
  const PersistenceSyncBanner({
    required this.state,
    required this.onDismiss,
    super.key,
  });

  final PersistenceSyncState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!state.isActive || state.message == null) {
      return const SizedBox.shrink();
    }

    final isLoading = state.status == PersistenceSyncStatus.loading;
    final type = switch (state.status) {
      PersistenceSyncStatus.saved => QuestraNotificationType.success,
      PersistenceSyncStatus.failed => QuestraNotificationType.error,
      PersistenceSyncStatus.loading ||
      PersistenceSyncStatus.idle => QuestraNotificationType.info,
    };
    return QuestraNotification(
      message: state.message!,
      type: type,
      onDismiss: onDismiss,
      isBusy: isLoading,
    );
  }
}
