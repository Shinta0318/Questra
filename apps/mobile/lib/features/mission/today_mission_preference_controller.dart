import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayMissionPreference {
  const TodayMissionPreference({
    this.dateKey,
    this.isResting = false,
    this.excludedMissionIds = const {},
    this.fiveMinuteMissionId,
  });

  final String? dateKey;
  final bool isResting;
  final Set<String> excludedMissionIds;
  final String? fiveMinuteMissionId;

  bool isFor(DateTime date) => dateKey == _dateKey(date);

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

final todayMissionPreferenceControllerProvider =
    NotifierProvider<TodayMissionPreferenceController, TodayMissionPreference>(
      TodayMissionPreferenceController.new,
    );

class TodayMissionPreferenceController
    extends Notifier<TodayMissionPreference> {
  @override
  TodayMissionPreference build() => const TodayMissionPreference();

  void chooseAnother(String missionId, {DateTime? now}) {
    final date = now ?? DateTime.now();
    final current = state.isFor(date)
        ? state.excludedMissionIds
        : const <String>{};
    state = TodayMissionPreference(
      dateKey: TodayMissionPreference._dateKey(date),
      excludedMissionIds: {...current, missionId},
    );
  }

  void useFiveMinutes(String missionId, {DateTime? now}) {
    final date = now ?? DateTime.now();
    state = TodayMissionPreference(
      dateKey: TodayMissionPreference._dateKey(date),
      fiveMinuteMissionId: missionId,
      excludedMissionIds: state.isFor(date)
          ? state.excludedMissionIds
          : const {},
    );
  }

  void restToday({DateTime? now}) {
    final date = now ?? DateTime.now();
    state = TodayMissionPreference(
      dateKey: TodayMissionPreference._dateKey(date),
      isResting: true,
    );
  }

  void resumeToday() => state = const TodayMissionPreference();
}
