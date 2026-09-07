import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/feature_flags/premium_unit_economics.dart';

void main() {
  const service = PremiumUnitEconomicsService();

  test('passes only when margin LTV/CAC and payback all pass', () {
    final result = service.evaluate(
      const PremiumEconomicsInput(
        monthlyPrice: 980,
        variableAiCost: 80,
        variableInfraCost: 20,
        storeFeeRate: 0.15,
        monthlyChurnRate: 0.04,
        cac: 1800,
      ),
    );
    expect(result.contributionMargin, greaterThanOrEqualTo(0.70));
    expect(result.ltvCac, greaterThanOrEqualTo(3));
    expect(result.paybackMonths, lessThanOrEqualTo(12));
    expect(result.passesValidationGate, isTrue);
  });

  test('fails closed when AI cost makes the package uneconomic', () {
    final result = service.evaluate(
      const PremiumEconomicsInput(
        monthlyPrice: 480,
        variableAiCost: 260,
        variableInfraCost: 50,
        storeFeeRate: 0.15,
        monthlyChurnRate: 0.08,
        cac: 2000,
      ),
    );
    expect(result.passesValidationGate, isFalse);
  });

  test('rejects invalid financial assumptions', () {
    expect(
      () => service.evaluate(
        const PremiumEconomicsInput(
          monthlyPrice: 0,
          variableAiCost: 0,
          variableInfraCost: 0,
          storeFeeRate: 0,
          monthlyChurnRate: 0.05,
          cac: 100,
        ),
      ),
      throwsArgumentError,
    );
  });
}
