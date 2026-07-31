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
}
