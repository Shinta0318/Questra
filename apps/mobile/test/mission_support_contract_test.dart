import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission_support/mission_support_model.dart';

void main() {
  test('only reviewed, current, HTTPS enterprise support can display', () {
    final valid = EnterpriseSupportProposal(
      enterpriseName: 'Example',
      role: EnterpriseSupportRole.coach,
      title: '学習支援',
      description: '審査済み支援',
      benefit: '教材',
      userCost: '無料',
      eligibility: '18歳以上',
      validUntil: DateTime.now().add(const Duration(days: 30)),
      destination: Uri.parse('https://example.com/apply'),
      disclosure: '企業提供の支援です。',
      selectionReason: 'Missionのテーマと一致',
      reviewed: true,
    );
    expect(valid.canDisplay, isTrue);
  });

  test('unreviewed or insecure support cannot display', () {
    final invalid = EnterpriseSupportProposal(
      enterpriseName: 'Example',
      role: EnterpriseSupportRole.sponsor,
      title: '支援',
      description: '未審査',
      benefit: '割引',
      userCost: '無料',
      eligibility: 'なし',
      validUntil: DateTime.now().add(const Duration(days: 30)),
      destination: Uri.parse('http://example.com'),
      disclosure: 'スポンサー',
      selectionReason: 'タグ一致',
      reviewed: false,
    );
    expect(invalid.canDisplay, isFalse);
  });
}
