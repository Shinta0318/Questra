import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/i18n/locale_format_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja');
    await initializeDateFormatting('en_US');
    await initializeDateFormatting('en_GB');
  });

  test('formats Japanese month and plural labels without English date order', () {
    const service = QuestraLocaleFormatService('ja');
    final date = DateTime(2027, 8, 3, 9, 30);

    expect(service.formatMonth(date), '2027 / 08');
    expect(service.formatShortDate(date), '2027/08/03');
    expect(service.pluralMissionCount(3), 'Mission 3件');
    expect(service.usesMondayWeekStart, isTrue);
  });

  test('separates en-US and en-GB week conventions', () {
    const us = QuestraLocaleFormatService('en_US');
    const gb = QuestraLocaleFormatService('en_GB');
    final date = DateTime(2027, 8, 3, 9, 30);

    expect(us.formatMonth(date), contains('Aug'));
    expect(us.pluralMissionCount(1), '1 Mission');
    expect(us.pluralMissionCount(2), '2 Missions');
    expect(us.usesMondayWeekStart, isFalse);
    expect(gb.usesMondayWeekStart, isTrue);
    expect(us.formatTime(date), contains('9:30'));
    expect(gb.formatCurrency(12), contains('£'));
    expect(us.formatCurrency(12), contains(r'$'));
  });

  test('detects RTL locales for future smoke testing', () {
    expect(const QuestraLocaleFormatService('ar').isRtl, isTrue);
    expect(const QuestraLocaleFormatService('en_US').isRtl, isFalse);
  });
}
