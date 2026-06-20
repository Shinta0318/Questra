import 'package:flutter_riverpod/flutter_riverpod.dart';

final arcBondServiceProvider = Provider<ArcBondService>(
  (ref) => const ArcBondService(),
);

enum ArcBondTier { firstLight, steadyOrbit, trustedNavigator, stellarBond }

class ArcBondState {
  const ArcBondState({
    required this.score,
    required this.tier,
    required this.label,
    required this.description,
    required this.progress,
  });

  final int score;
  final ArcBondTier tier;
  final String label;
  final String description;
  final double progress;
}

class ArcBondService {
  const ArcBondService();

  ArcBondState resolve(int score) {
    final normalized = score.clamp(0, 100);
    final tier = _tierFor(normalized);
    return ArcBondState(
      score: normalized,
      tier: tier,
      label: _labelFor(tier),
      description: _descriptionFor(tier),
      progress: normalized / 100,
    );
  }

  ArcBondTier _tierFor(int score) {
    if (score >= 80) {
      return ArcBondTier.stellarBond;
    }
    if (score >= 50) {
      return ArcBondTier.trustedNavigator;
    }
    if (score >= 20) {
      return ArcBondTier.steadyOrbit;
    }
    return ArcBondTier.firstLight;
  }

  String _labelFor(ArcBondTier tier) {
    return switch (tier) {
      ArcBondTier.firstLight => 'First Light',
      ArcBondTier.steadyOrbit => 'Steady Orbit',
      ArcBondTier.trustedNavigator => 'Trusted Navigator',
      ArcBondTier.stellarBond => 'Stellar Bond',
    };
  }

  String _descriptionFor(ArcBondTier tier) {
    return switch (tier) {
      ArcBondTier.firstLight => 'Arcとの航路が灯りはじめています。',
      ArcBondTier.steadyOrbit => 'QuestとTrailが少しずつArcとの文脈になっています。',
      ArcBondTier.trustedNavigator => 'Arcはあなたの挑戦の流れをかなり覚えています。',
      ArcBondTier.stellarBond => '長い航海の記録がArcとの強い星図になっています。',
    };
  }
}
