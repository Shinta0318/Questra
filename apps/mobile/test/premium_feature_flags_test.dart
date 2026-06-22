import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/feature_flags/premium_feature_flags.dart';

void main() {
  test('all future Premium candidates remain open during beta', () {
    const flags = PremiumFeatureFlags();

    for (final capability in PremiumCapability.values) {
      expect(flags.canUse(capability), isTrue, reason: capability.name);
      expect(flags.accessFor(capability).isBlocked, isFalse);
    }
  });

  test('feature flags can represent future Premium candidates', () {
    const flags = PremiumFeatureFlags();
    final access = flags.accessFor(PremiumCapability.threeDArc);

    expect(access.futurePremiumCandidate, isTrue);
    expect(access.reason, contains('Beta'));
  });
}
