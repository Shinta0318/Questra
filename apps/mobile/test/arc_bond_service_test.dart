import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_bond_service.dart';

void main() {
  const service = ArcBondService();

  test('resolves low Bond as first light', () {
    final bond = service.resolve(5);

    expect(bond.tier, ArcBondTier.firstLight);
    expect(bond.progress, 0.05);
    expect(bond.description, contains('灯り'));
  });

  test('caps Bond score and resolves highest tier', () {
    final bond = service.resolve(140);

    expect(bond.score, 100);
    expect(bond.tier, ArcBondTier.stellarBond);
    expect(bond.progress, 1);
  });
}
