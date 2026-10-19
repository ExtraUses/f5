import 'package:flutter_test/flutter_test.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/habits/data/habit.dart';

import 'support/app_harness.dart';

void main() {
  final today = AppClock.today();
  final yesterday = today.addDays(-1);

  Habit everyThree({DateTime? start}) => testHabit(
        id: 'sink',
        name: 'Clean the sink',
        interval: HabitInterval.everyXDays,
        daysOld: 0,
      ).copyWith(scheduleEvery: 3, scheduleStart: start);

  test('without a start day the count begins the day it was created', () {
    final habit = everyThree();
    expect(habit.isScheduledOn(today), isTrue);
    expect(habit.isScheduledOn(yesterday), isFalse);
  });

  test('a start day in the past moves the whole count', () {
    final habit = everyThree(start: yesterday);
    expect(habit.isScheduledOn(yesterday), isTrue);
    expect(habit.isScheduledOn(today), isFalse);
    expect(habit.isScheduledOn(yesterday.addDays(3)), isTrue);
  });

  test('the start day survives a backup, and old backups have none', () {
    final map = everyThree(start: yesterday).toMap();
    expect(Habit.fromMap(map).scheduleStart, yesterday);
    expect(Habit.fromMap(map..remove('scheduleStart')).scheduleStart, isNull);
  });
}
