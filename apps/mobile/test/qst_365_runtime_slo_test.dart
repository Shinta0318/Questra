import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/observability/runtime_evidence.dart';
import 'package:questra/core/observability/runtime_slo.dart';

void main() {
  const evaluator = RuntimeSloEvaluator();

  test('healthy window permits continued internal distribution', () {
    final decision = evaluator.evaluate(
      const RuntimeSloWindow(
        coreOperations: 10000,
        failedCoreOperations: 2,
        sessions: 10000,
        crashedSessions: 2,
        mutationP95Ms: 420,
        listReadP95Ms: 850,
      ),
    );
    expect(decision.distributionAllowed, isTrue);
    expect(decision.alerts, isEmpty);
  });

  test('S1 pauses rollout without claiming data rollback is required', () {
    final decision = evaluator.evaluate(
      const RuntimeSloWindow(
        coreOperations: 1000,
        failedCoreOperations: 5,
        sessions: 1000,
        crashedSessions: 6,
        mutationP95Ms: 750,
        listReadP95Ms: 1200,
      ),
    );
    expect(decision.distributionAllowed, isFalse);
    expect(decision.rollbackRequired, isFalse);
    expect(decision.alerts.single.severity, RuntimeEvidenceSeverity.s1);
  });

  test('cross-account access is an immediate S0 rollback decision', () {
    final decision = evaluator.evaluate(
      const RuntimeSloWindow(
        coreOperations: 10000,
        failedCoreOperations: 0,
        sessions: 10000,
        crashedSessions: 0,
        mutationP95Ms: 300,
        listReadP95Ms: 600,
        crossAccountViolation: true,
      ),
    );
    expect(decision.distributionAllowed, isFalse);
    expect(decision.rollbackRequired, isTrue);
    expect(
      decision.alerts.first.responseAction,
      'stop_distribution_and_rollback_candidate',
    );
  });
}
