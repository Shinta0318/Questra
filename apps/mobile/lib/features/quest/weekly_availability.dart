enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

class WeeklyAvailability {
  const WeeklyAvailability({required this.minutesByDay});

  final Map<Weekday, int> minutesByDay;

  int get totalMinutes =>
      minutesByDay.values.fold(0, (sum, value) => sum + value.clamp(0, 1440));

  Map<String, int> toJson() => {
    for (final day in Weekday.values)
      day.name: (minutesByDay[day] ?? 0).clamp(0, 1440),
  };
}
