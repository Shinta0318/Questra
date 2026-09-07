import 'runtime_evidence.dart';

class RuntimeSloWindow {
  const RuntimeSloWindow({
    required this.coreOperations,
    required this.failedCoreOperations,
    required this.sessions,
    required this.crashedSessions,
    required this.mutationP95Ms,
    required this.listReadP95Ms,
    this.s0Events = 0,
    this.s1Events = 0,
    this.crossAccountViolation = false,
    this.repeatedDataLoss = false,
  });

  final int coreOperations;
  final int failedCoreOperations;
  final int sessions;
  final int crashedSessions;
  final int mutationP95Ms;
  final int listReadP95Ms;
  final int s0Events;
  final int s1Events;
  final bool crossAccountViolation;
  final bool repeatedDataLoss;

  double get coreSuccessRate => coreOperations <= 0
      ? 0
      : (coreOperations - failedCoreOperations) / coreOperations;

  double get crashFreeRate =>
      sessions <= 0 ? 0 : (sessions - crashedSessions) / sessions;
}

class RuntimeSloAlert {
  const RuntimeSloAlert({
    required this.code,
    required this.severity,
    required this.responseAction,
  });

  final String code;
  final RuntimeEvidenceSeverity severity;
  final String responseAction;
}

class RuntimeSloDecision {
  const RuntimeSloDecision({
    required this.distributionAllowed,
    required this.rollbackRequired,
    required this.coreJourneyBurnRate,
    required this.crashFreeBurnRate,
    required this.alerts,
  });

  final bool distributionAllowed;
  final bool rollbackRequired;
  final double coreJourneyBurnRate;
  final double crashFreeBurnRate;
  final List<RuntimeSloAlert> alerts;
}

class RuntimeSloEvaluator {
  const RuntimeSloEvaluator();

  static const coreJourneyTarget = 0.999;
  static const crashFreeTarget = 0.995;
  static const mutationP95TargetMs = 500;
  static const listReadP95TargetMs = 1000;

  RuntimeSloDecision evaluate(RuntimeSloWindow window) {
    final alerts = <RuntimeSloAlert>[];
    final hasS0 =
        window.crossAccountViolation ||
        window.repeatedDataLoss ||
        window.s0Events > 0;
    if (hasS0) {
      alerts.add(
        const RuntimeSloAlert(
          code: 'runtime_integrity_s0',
          severity: RuntimeEvidenceSeverity.s0,
          responseAction: 'stop_distribution_and_rollback_candidate',
        ),
      );
    }
    if (window.s1Events > 0 ||
        window.coreSuccessRate < coreJourneyTarget ||
        window.crashFreeRate < crashFreeTarget ||
        window.mutationP95Ms > mutationP95TargetMs ||
        window.listReadP95Ms > listReadP95TargetMs) {
      alerts.add(
        const RuntimeSloAlert(
          code: 'runtime_slo_s1',
          severity: RuntimeEvidenceSeverity.s1,
          responseAction: 'pause_rollout_and_page_incident_owner',
        ),
      );
    }
    return RuntimeSloDecision(
      distributionAllowed: alerts.isEmpty,
      rollbackRequired: hasS0,
      coreJourneyBurnRate: _burnRate(
        observed: window.coreSuccessRate,
        target: coreJourneyTarget,
      ),
      crashFreeBurnRate: _burnRate(
        observed: window.crashFreeRate,
        target: crashFreeTarget,
      ),
      alerts: List.unmodifiable(alerts),
    );
  }

  double _burnRate({required double observed, required double target}) {
    return ((1 - observed) / (1 - target)).clamp(0, double.infinity);
  }
}
