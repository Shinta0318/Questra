import 'package:intl/intl.dart';

class QuestraLocaleFormatService {
  const QuestraLocaleFormatService(this.localeName);

  final String localeName;

  bool get isJapanese => localeName.startsWith('ja');
  bool get isEnglish => localeName.startsWith('en');
  bool get usesMondayWeekStart =>
      localeName == 'en_GB' || localeName == 'en-GB' || isJapanese;
  bool get isRtl => const {'ar', 'he', 'fa', 'ur'}.contains(
    localeName.split(RegExp('[-_]')).first,
  );

  String formatMonth(DateTime value) {
    if (isJapanese) return DateFormat('yyyy / MM', 'ja').format(value);
    return DateFormat.yMMM(_intlLocale).format(value);
  }

  String formatShortDate(DateTime value) {
    if (isJapanese) return DateFormat('yyyy/MM/dd', 'ja').format(value);
    return DateFormat.yMd(_intlLocale).format(value);
  }

  String formatTime(DateTime value) {
    if (isJapanese) return DateFormat.Hm(_intlLocale).format(value);
    return DateFormat.jm(_intlLocale).format(value);
  }

  String formatCurrency(num value, {String? currencyCode}) {
    final code = currencyCode ?? _defaultCurrencyCode;
    return NumberFormat.simpleCurrency(
      locale: _intlLocale,
      name: code,
    ).format(value);
  }

  String pluralMissionCount(int count) {
    if (isJapanese) return 'Mission $count件';
    return Intl.plural(
      count,
      locale: _intlLocale,
      one: '$count Mission',
      other: '$count Missions',
    );
  }

  String get _intlLocale => localeName.replaceAll('-', '_');

  String get _defaultCurrencyCode {
    if (isJapanese) return 'JPY';
    if (_intlLocale == 'en_GB') return 'GBP';
    return 'USD';
  }
}
