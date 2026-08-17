enum SubscriptionState { free, premium, gracePeriod, unknown }

enum AiPlanningOperation {
  arcConsultation,
  questPlanning,
  basicMissionPlanning,
  missionRedesign,
  detailedProgressReview,
}

class AiUsageQuota {
  const AiUsageQuota({
    required this.operation,
    required this.used,
    required this.hardLimit,
    required this.resetsAt,
  });

  final AiPlanningOperation operation;
  final int used;
  final int? hardLimit;
  final DateTime? resetsAt;

  int? get remaining =>
      hardLimit == null ? null : (hardLimit! - used).clamp(0, hardLimit!);
}

class AiEntitlementSnapshot {
  const AiEntitlementSnapshot({
    required this.subscriptionState,
    required this.serverVerified,
    required this.quotas,
  });

  const AiEntitlementSnapshot.betaOpen()
    : subscriptionState = SubscriptionState.free,
      serverVerified = false,
      quotas = const {};

  final SubscriptionState subscriptionState;
  final bool serverVerified;
  final Map<AiPlanningOperation, AiUsageQuota> quotas;
}

enum AiEntitlementReason {
  allowedByServer,
  betaOpenAccess,
  quotaExhausted,
  verificationRequired,
}

class AiEntitlementDecision {
  const AiEntitlementDecision({
    required this.allowed,
    required this.reason,
    this.remaining,
    this.resetsAt,
  });

  final bool allowed;
  final AiEntitlementReason reason;
  final int? remaining;
  final DateTime? resetsAt;
}

class AiEntitlementPolicy {
  const AiEntitlementPolicy({this.betaOpenAccess = true});

  final bool betaOpenAccess;

  AiEntitlementDecision evaluate(
    AiPlanningOperation operation,
    AiEntitlementSnapshot snapshot,
  ) {
    if (!snapshot.serverVerified) {
      return AiEntitlementDecision(
        allowed: betaOpenAccess,
        reason: betaOpenAccess
            ? AiEntitlementReason.betaOpenAccess
            : AiEntitlementReason.verificationRequired,
      );
    }

    final quota = snapshot.quotas[operation];
    if (quota == null || quota.hardLimit == null) {
      return const AiEntitlementDecision(
        allowed: true,
        reason: AiEntitlementReason.allowedByServer,
      );
    }
    final remaining = quota.remaining ?? 0;
    return AiEntitlementDecision(
      allowed: remaining > 0,
      reason: remaining > 0
          ? AiEntitlementReason.allowedByServer
          : AiEntitlementReason.quotaExhausted,
      remaining: remaining,
      resetsAt: quota.resetsAt,
    );
  }
}
