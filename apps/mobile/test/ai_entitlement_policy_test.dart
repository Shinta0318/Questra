import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/feature_flags/ai_entitlement_policy.dart';

void main() {
  test('beta remains open when no server entitlement is available', () {
    final decision = const AiEntitlementPolicy().evaluate(
      AiPlanningOperation.arcConsultation,
      AiEntitlementSnapshot.betaOpen(),
    );

    expect(decision.allowed, isTrue);
    expect(decision.reason, AiEntitlementReason.betaOpenAccess);
  });

  test('server quota exhaustion cannot be unlocked by a client flag', () {
    final snapshot = AiEntitlementSnapshot(
      subscriptionState: SubscriptionState.free,
      serverVerified: true,
      quotas: {
        AiPlanningOperation.missionRedesign: AiUsageQuota(
          operation: AiPlanningOperation.missionRedesign,
          used: 3,
          hardLimit: 3,
          resetsAt: DateTime.utc(2026, 9),
        ),
      },
    );
    const policy = AiEntitlementPolicy(betaOpenAccess: true);

    final decision = policy.evaluate(
      AiPlanningOperation.missionRedesign,
      snapshot,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, AiEntitlementReason.quotaExhausted);
  });

  test('an unlimited server policy remains available', () {
    final snapshot = AiEntitlementSnapshot(
      subscriptionState: SubscriptionState.free,
      serverVerified: true,
      quotas: {
        AiPlanningOperation.questPlanning: const AiUsageQuota(
          operation: AiPlanningOperation.questPlanning,
          used: 42,
          hardLimit: null,
          resetsAt: null,
        ),
      },
    );

    final decision = const AiEntitlementPolicy().evaluate(
      AiPlanningOperation.questPlanning,
      snapshot,
    );
    expect(decision.allowed, isTrue);
  });
}
