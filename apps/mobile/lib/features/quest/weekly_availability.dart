enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

extension WeekdayLabel on Weekday {
  String get shortLabel => switch (this) {
    Weekday.monday => '月',
    Weekday.tuesday => '火',
    Weekday.wednesday => '水',
    Weekday.thursday => '木',
    Weekday.friday => '金',
    Weekday.saturday => '土',
    Weekday.sunday => '日',
  };

  static Weekday fromDateTime(DateTime date) =>
      Weekday.values[date.weekday - 1];
}

class WeeklyAvailability {
  const WeeklyAvailability({required this.minutesByDay});

  const WeeklyAvailability.empty() : minutesByDay = const {};

  final Map<Weekday, int> minutesByDay;

  int get totalMinutes =>
      minutesByDay.values.fold(0, (sum, value) => sum + value.clamp(0, 1440));

  int minutesFor(Weekday day) => (minutesByDay[day] ?? 0).clamp(0, 1440);

  WeeklyAvailability copyWithDay(Weekday day, int minutes) {
    return WeeklyAvailability(
      minutesByDay: {...minutesByDay, day: minutes.clamp(0, 1440)},
    );
  }

  factory WeeklyAvailability.fromJson(Map<String, dynamic> json) {
    int valueFor(Weekday day) {
      final value = json[day.name] ?? json['${day.name}_minutes'];
      return ((value as num?)?.round() ?? 0).clamp(0, 1440);
    }

    return WeeklyAvailability(
      minutesByDay: {for (final day in Weekday.values) day: valueFor(day)},
    );
  }

  Map<String, int> toJson() => {
    for (final day in Weekday.values)
      day.name: (minutesByDay[day] ?? 0).clamp(0, 1440),
  };
}
