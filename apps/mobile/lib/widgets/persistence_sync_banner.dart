import 'dart:async';

import 'package:flutter/material.dart';

import '../core/feature_flags/notification_feature_flags.dart';
import '../core/persistence/persistence_sync_state.dart';
import 'feedback/questra_notification.dart';

class PersistenceSyncBanner extends StatefulWidget {
  const PersistenceSyncBanner({
    required this.state,
    required this.onDismiss,
    this.onRetry,
    this.successDuration = const Duration(seconds: 4),
    super.key,
  });

  final PersistenceSyncState state;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;
  final Duration successDuration;

  @override
  State<PersistenceSyncBanner> createState() => _PersistenceSyncBannerState();
}

class _PersistenceSyncBannerState extends State<PersistenceSyncBanner> {
  Timer? _dismissTimer;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _scheduleDismiss();
  }

  @override
  void didUpdateWidget(covariant PersistenceSyncBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.status != widget.state.status ||
        oldWidget.state.message != widget.state.message) {
      _hidden = false;
      _scheduleDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    if (!const NotificationFeatureFlags().policyV2Enabled ||
        widget.state.status != PersistenceSyncStatus.saved) {
      return;
    }
    _dismissTimer = Timer(widget.successDuration, _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    if (!mounted || _hidden) return;
    setState(() => _hidden = true);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (_hidden || !state.isActive || state.message == null) {
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
      onRetry: state.isFailed ? widget.onRetry : null,
      onDismiss: isLoading ? null : _dismiss,
      isBusy: isLoading,
    );
  }
}
