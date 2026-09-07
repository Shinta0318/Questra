enum RuntimeEvidenceType {
  appCrash,
  flutterFrameworkError,
  unhandledAsyncError,
  persistenceFailure,
  authFailure,
  mediaFailure,
  aiFallback,
}

enum RuntimeEvidenceSeverity { s0, s1, s2, s3 }

class RuntimeEvidence {
  const RuntimeEvidence({
    required this.eventId,
    required this.occurredAt,
    required this.buildVersion,
    required this.environment,
    required this.platform,
    required this.surface,
    required this.operation,
    required this.type,
    required this.severity,
    required this.errorCode,
    required this.correlationId,
    required this.handled,
    required this.fallbackUsed,
  });

  final String eventId;
  final DateTime occurredAt;
  final String buildVersion;
  final String environment;
  final String platform;
  final String surface;
  final String operation;
  final RuntimeEvidenceType type;
  final RuntimeEvidenceSeverity severity;
  final String errorCode;
  final String correlationId;
  final bool handled;
  final bool fallbackUsed;

  Map<String, Object> toSafeMap() => {
    'event_id': eventId,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'build_version': buildVersion,
    'environment': environment,
    'platform': platform,
    'surface': surface,
    'operation': operation,
    'event_type': type.name,
    'severity': severity.name.toUpperCase(),
    'error_code': errorCode,
    'correlation_id': correlationId,
    'handled': handled,
    'fallback_used': fallbackUsed,
  };
}

abstract interface class RuntimeEvidenceSink {
  Future<void> record(RuntimeEvidence evidence);
}

class NoopRuntimeEvidenceSink implements RuntimeEvidenceSink {
  const NoopRuntimeEvidenceSink();

  @override
  Future<void> record(RuntimeEvidence evidence) async {}
}

class RuntimeEvidencePolicy {
  const RuntimeEvidencePolicy();

  static final _safeToken = RegExp(r'^[a-zA-Z0-9._:-]{1,120}$');

  bool accepts(RuntimeEvidence evidence) {
    return _safeToken.hasMatch(evidence.eventId) &&
        _safeToken.hasMatch(evidence.correlationId) &&
        _safeToken.hasMatch(evidence.environment) &&
        _safeToken.hasMatch(evidence.platform) &&
        _safeToken.hasMatch(evidence.surface) &&
        _safeToken.hasMatch(evidence.operation) &&
        _safeToken.hasMatch(evidence.errorCode) &&
        _safeToken.hasMatch(evidence.buildVersion);
  }
}
