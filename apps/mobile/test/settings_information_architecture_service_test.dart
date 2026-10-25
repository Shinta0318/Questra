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
    expect(overview.sections.first.title, '接続状態');
    expect(overview.sections.first.type, SettingsSectionType.connection);
    expect(
      overview.sections.map((section) => section.type),
      contains(SettingsSectionType.experience),
    );
    expect(overview.sections.last.type, SettingsSectionType.feedback);
    expect(
      overview.sections
          .firstWhere((section) => section.type == SettingsSectionType.trust)
          .summary,
      contains('データ保護'),
    );
  });

  test('offline preview does not promise durable account data', () {
    final overview = service.buildOverview(localMockPreview: true);
    final data = overview.sections.firstWhere(
      (section) => section.type == SettingsSectionType.dataRequest,
    );

    expect(data.summary, contains('再読み込みで消えます'));
    expect(data.statusLabel, 'プレビュー');
  });
}
