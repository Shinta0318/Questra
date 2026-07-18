import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/settings/settings_information_architecture_service.dart';

void main() {
  const service = SettingsInformationArchitectureService();

  test('builds Settings information architecture overview', () {
    final overview = service.buildOverview();

    expect(overview.heading, 'Settings Map');
    expect(
      overview.sections.map((section) => section.type),
      containsAll(SettingsSectionType.values),
    );
    expect(overview.sections.first.title, 'Arcチュートリアル');
    expect(overview.sections.last.type, SettingsSectionType.consent);
    expect(
      overview.sections
          .firstWhere((section) => section.type == SettingsSectionType.trust)
          .summary,
      contains('所有者境界'),
    );
  });
}
