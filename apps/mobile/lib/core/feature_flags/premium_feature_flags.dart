enum PremiumCapability {
  advancedArcMemory,
  extendedDreamBoard,
  guildBoosts,
  starMapDeepRecommendations,
  threeDArc,
  exportArchive,
}

class PremiumFeatureAccess {
  const PremiumFeatureAccess({
    required this.capability,
    required this.enabledForBeta,
    required this.futurePremiumCandidate,
    required this.reason,
  });

  final PremiumCapability capability;
  final bool enabledForBeta;
  final bool futurePremiumCandidate;
  final String reason;

  bool get isBlocked => !enabledForBeta;
}

class PremiumFeatureFlags {
  const PremiumFeatureFlags({this.betaOpenAccess = true});

  final bool betaOpenAccess;

  List<PremiumFeatureAccess> get all => PremiumCapability.values
      .map((capability) => accessFor(capability))
      .toList(growable: false);

  PremiumFeatureAccess accessFor(PremiumCapability capability) {
    return PremiumFeatureAccess(
      capability: capability,
      enabledForBeta: betaOpenAccess,
      futurePremiumCandidate: true,
      reason: _reasonFor(capability),
    );
  }

  bool canUse(PremiumCapability capability) {
    return accessFor(capability).enabledForBeta;
  }

  String _reasonFor(PremiumCapability capability) {
    return switch (capability) {
      PremiumCapability.advancedArcMemory =>
        'BetaではArc Memoryの信頼性検証を優先するため開放します。',
      PremiumCapability.extendedDreamBoard =>
        'Dream BoardはQuest作成体験を補助するためBetaでは開放します。',
      PremiumCapability.guildBoosts => 'Guildの価値検証を妨げないためBetaでは開放します。',
      PremiumCapability.starMapDeepRecommendations =>
        'Star Map推薦の精度検証を優先するためBetaでは開放します。',
      PremiumCapability.threeDArc => '将来の3D Arc準備枠であり、Betaでは表示制限をかけません。',
      PremiumCapability.exportArchive => 'ユーザーデータの持ち出し導線は信頼性に関わるためBetaでは開放します。',
    };
  }
}
