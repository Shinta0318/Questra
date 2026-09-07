import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/settings/settings_information_architecture_service.dart';

void main() {
  const service = SettingsInformationArchitectureService();

  test('builds Settings information architecture overview', () {
    final overview = service.buildOverview();

    expect(overview.heading, '設定メニュー');
    expect(
      overview.sections.map((section) => section.type),
      containsAll(SettingsSectionType.values),
    );
    expect(overview.sections.first.title, '操作と演出');
    expect(overview.sections.first.type, SettingsSectionType.experience);
    expect(overview.sections.last.type, SettingsSectionType.feedback);
    expect(
      overview.sections
          .firstWhere((section) => section.type == SettingsSectionType.trust)
          .summary,
      contains('データ保護'),
    );
  });
}
