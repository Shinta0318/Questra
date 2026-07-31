import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/weekly_availability.dart';

void main() {
  test('weekly availability totals explicit per-day minutes', () {
    const availability = WeeklyAvailability(
      minutesByDay: {
        Weekday.monday: 15,
        Weekday.tuesday: 15,
        Weekday.saturday: 60,
      },
    );
    expect(availability.totalMinutes, 90);
    expect(availability.toJson()['sunday'], 0);
  });

  test('weekly availability restores database column names', () {
    final availability = WeeklyAvailability.fromJson({
      'monday_minutes': 45,
      'sunday_minutes': 90,
    });
    expect(availability.minutesFor(Weekday.monday), 45);
    expect(availability.minutesFor(Weekday.sunday), 90);
    expect(WeekdayLabel.fromDateTime(DateTime(2026, 8, 1)), Weekday.saturday);
  });
}
