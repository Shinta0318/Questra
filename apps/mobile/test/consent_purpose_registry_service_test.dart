import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trust/consent_purpose_registry_service.dart';

void main() {
  const service = ConsentPurposeRegistryService();

  test('builds purpose-specific consent registry', () {
    final registry = service.buildRegistry();

    expect(registry.heading, 'データ利用の設定');
    expect(registry.summary, contains('基本機能は利用できます'));
    expect(
      registry.purposes.map((purpose) => purpose.purpose),
      containsAll(ConsentPurpose.values),
    );
    expect(
      registry.purposes
          .firstWhere(
            (purpose) =>
                purpose.purpose == ConsentPurpose.businessRecommendations,
          )
          .dataScope,
      contains('Mission支援分類'),
    );
    expect(registry.purposes.every((purpose) => purpose.canWithdraw), isTrue);
    expect(registry.guardrails, contains('採用、保険、信用評価へ無断転用しない'));
  });
}
