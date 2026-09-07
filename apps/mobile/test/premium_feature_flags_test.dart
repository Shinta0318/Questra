import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/feature_flags/premium_feature_flags.dart';

void main() {
  test('beta opens allowed capabilities but never paid Guild exposure', () {
    const flags = PremiumFeatureFlags();

    for (final capability in PremiumCapability.values) {
      final expected = capability != PremiumCapability.guildBoosts;
      expect(flags.canUse(capability), expected, reason: capability.name);
      expect(flags.accessFor(capability).isBlocked, !expected);
    }
  });

  test('only the single accompaniment-depth package is a candidate', () {
    const flags = PremiumFeatureFlags();
    final access = flags.accessFor(PremiumCapability.missionRedesign);

    expect(access.futurePremiumCandidate, isTrue);
    expect(
      flags.accessFor(PremiumCapability.threeDArc).futurePremiumCandidate,
      isFalse,
    );
    expect(
      flags.accessFor(PremiumCapability.guildBoosts).futurePremiumCandidate,
      isFalse,
    );
    expect(
      flags.accessFor(PremiumCapability.exportArchive).futurePremiumCandidate,
      isFalse,
    );
  });

  test('core Arc and planning capabilities are not Premium candidates', () {
    const flags = PremiumFeatureFlags();

    expect(
      flags.accessFor(PremiumCapability.arcConsultation).futurePremiumCandidate,
      isFalse,
    );
    expect(
      flags
          .accessFor(PremiumCapability.basicMissionPlanning)
          .futurePremiumCandidate,
      isFalse,
    );
    expect(
      flags.accessFor(PremiumCapability.missionRedesign).futurePremiumCandidate,
      isTrue,
    );
  });

  test('turning off beta candidates never blocks the Free core', () {
    const flags = PremiumFeatureFlags(betaOpenAccess: false);

    expect(flags.canUse(PremiumCapability.arcConsultation), isTrue);
    expect(flags.canUse(PremiumCapability.questPlanning), isTrue);
    expect(flags.canUse(PremiumCapability.basicMissionPlanning), isTrue);
    expect(flags.canUse(PremiumCapability.exportArchive), isTrue);
    expect(flags.canUse(PremiumCapability.guildBoosts), isFalse);
    expect(flags.canUse(PremiumCapability.missionRedesign), isFalse);
  });
}
