import 'package:flutter_riverpod/flutter_riverpod.dart';

const bool arcRemoteProvenanceV1Enabled = bool.fromEnvironment(
  'ARC_REMOTE_PROVENANCE_V1',
  defaultValue: true,
);

enum ArcRemoteResponseState { notChecked, verified, degraded, preview }

enum ArcRemoteLatencyClass { fast, normal, slow }

class ArcRemoteStatus {
  const ArcRemoteStatus({
    this.responseState = ArcRemoteResponseState.notChecked,
    this.sourceClass,
    this.checkedAt,
    this.traceId,
    this.latencyClass,
    this.failureReason,
  });

  final ArcRemoteResponseState responseState;
  final String? sourceClass;
  final DateTime? checkedAt;
  final String? traceId;
  final ArcRemoteLatencyClass? latencyClass;
  final String? failureReason;

  bool get isVerified => responseState == ArcRemoteResponseState.verified;
}

final arcRemoteStatusProvider =
    NotifierProvider<ArcRemoteStatusController, ArcRemoteStatus>(
      ArcRemoteStatusController.new,
    );

class ArcRemoteStatusController extends Notifier<ArcRemoteStatus> {
  @override
  ArcRemoteStatus build() => const ArcRemoteStatus();

  void markVerified({
    required String? traceId,
    required ArcRemoteLatencyClass latencyClass,
    DateTime? checkedAt,
  }) {
    if (!arcRemoteProvenanceV1Enabled) return;
    state = ArcRemoteStatus(
      responseState: ArcRemoteResponseState.verified,
      sourceClass: 'online',
      checkedAt: (checkedAt ?? DateTime.now()).toUtc(),
      traceId: sanitizeArcTraceId(traceId),
      latencyClass: latencyClass,
    );
  }

  void markDegraded({required String failureReason, DateTime? checkedAt}) {
    if (!arcRemoteProvenanceV1Enabled) return;
    state = ArcRemoteStatus(
      responseState: ArcRemoteResponseState.degraded,
      sourceClass: 'degraded',
      checkedAt: (checkedAt ?? DateTime.now()).toUtc(),
      failureReason: sanitizeArcFailureReason(failureReason),
    );
  }

  void markPreview({DateTime? checkedAt}) {
    if (!arcRemoteProvenanceV1Enabled) return;
    state = ArcRemoteStatus(
      responseState: ArcRemoteResponseState.preview,
      sourceClass: 'preview',
      checkedAt: (checkedAt ?? DateTime.now()).toUtc(),
    );
  }
}

String? sanitizeArcTraceId(String? value) {
  final candidate = value?.trim();
  if (candidate == null || candidate.isEmpty || candidate.length > 64) {
    return null;
  }
  return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(candidate) ? candidate : null;
}

String sanitizeArcFailureReason(String value) {
  const allowed = {'timeout', 'remote_failure', 'invalid_response'};
  return allowed.contains(value) ? value : 'remote_failure';
}

ArcRemoteLatencyClass arcRemoteLatencyClass(Duration duration) {
  if (duration <= const Duration(milliseconds: 1500)) {
    return ArcRemoteLatencyClass.fast;
  }
  if (duration <= const Duration(seconds: 5)) {
    return ArcRemoteLatencyClass.normal;
  }
  return ArcRemoteLatencyClass.slow;
}
