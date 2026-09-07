class PremiumEconomicsInput {
  const PremiumEconomicsInput({
    required this.monthlyPrice,
    required this.variableAiCost,
    required this.variableInfraCost,
    required this.storeFeeRate,
    required this.monthlyChurnRate,
    required this.cac,
  });

  final double monthlyPrice;
  final double variableAiCost;
  final double variableInfraCost;
  final double storeFeeRate;
  final double monthlyChurnRate;
  final double cac;
}

class PremiumEconomicsResult {
  const PremiumEconomicsResult({
    required this.contributionMargin,
    required this.ltvCac,
    required this.paybackMonths,
    required this.passesValidationGate,
  });

  final double contributionMargin;
  final double ltvCac;
  final double paybackMonths;
  final bool passesValidationGate;
}

class PremiumUnitEconomicsService {
  const PremiumUnitEconomicsService();

  PremiumEconomicsResult evaluate(PremiumEconomicsInput input) {
    if (input.monthlyPrice <= 0 ||
        input.variableAiCost < 0 ||
        input.variableInfraCost < 0 ||
        input.storeFeeRate < 0 ||
        input.storeFeeRate >= 1 ||
        input.monthlyChurnRate <= 0 ||
        input.monthlyChurnRate > 1 ||
        input.cac <= 0) {
      throw ArgumentError('Premium economics input is invalid.');
    }
    final netRevenue = input.monthlyPrice * (1 - input.storeFeeRate);
    final contribution =
        netRevenue - input.variableAiCost - input.variableInfraCost;
    final margin = contribution / input.monthlyPrice;
    final ltv = contribution / input.monthlyChurnRate;
    final ltvCac = ltv / input.cac;
    final payback = contribution <= 0
        ? double.infinity
        : input.cac / contribution;
    return PremiumEconomicsResult(
      contributionMargin: margin,
      ltvCac: ltvCac,
      paybackMonths: payback,
      passesValidationGate: margin >= 0.70 && ltvCac >= 3 && payback <= 12,
    );
  }
}
