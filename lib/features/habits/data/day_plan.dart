import 'package:flutter/foundation.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/todos/data/todo.dart';

@immutable
class DaySlot {
  const DaySlot({
    required this.start,
    required this.end,
    this.habit,
    this.todo,
  });

  final int start;
  final int end;
  final Habit? habit;
  final Todo? todo;

  bool get isGap => habit == null && todo == null;

  int get minutes => end - start;
}

@immutable
class DayPlan {
  const DayPlan({required this.slots, required this.anytime});

  final List<DaySlot> slots;
  final List<Habit> anytime;

  bool get isEmpty => slots.isEmpty && anytime.isEmpty;

  Iterable<Habit> get planned =>
      slots.where((s) => s.habit != null).map((s) => s.habit!);

  static bool isDueOn(Habit habit, DateTime day) =>
      !habit.isArchived &&
      habit.kind != HabitKind.negative &&
      !day.atMidnight.isBefore(habit.startedAt) &&
      habit.isScheduledOn(day) &&
      !habit.isPausedOn(day) &&
      !habit.isDoneAheadOn(day);

  static DayPlan of(
    List<Habit> habits,
    DateTime day, {
    List<Todo> todos = const [],
  }) {
    final due = habits.where((h) => isDueOn(h, day)).toList();

    final planned = [
      for (final habit in due.where((h) => h.isPlanned))
        DaySlot(start: habit.startMinute, end: habit.endMinute, habit: habit),
      for (final todo in todos.where((t) => t.minutes != null))
        DaySlot(
          start: todo.minutes!,
          end: todo.minutes! + (todo.estimate ?? 0),
          todo: todo,
        ),
    ]..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        final byEnd = a.end.compareTo(b.end);
        if (byEnd != 0) return byEnd;
        if ((a.habit == null) != (b.habit == null)) {
          return a.habit == null ? 1 : -1;
        }
        return (a.habit?.order ?? 0).compareTo(b.habit?.order ?? 0);
      });

    final slots = <DaySlot>[];
    var reached = -1;
    for (final slot in planned) {
      if (reached >= 0 && slot.start > reached) {
        slots.add(DaySlot(start: reached, end: slot.start));
      }
      slots.add(slot);
      if (slot.end > reached) reached = slot.end;
    }

    return DayPlan(
      slots: slots,
      anytime: due.where((h) => !h.isPlanned).toList(),
    );
  }
}

String minuteLabel(int minute, {bool hour24 = true}) {
  final total = minute.clamp(0, Habit.dayMinutes);
  final h = (total ~/ 60) % 24;
  final m = total % 60;
  if (hour24) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  final suffix = h < 12 ? 'AM' : 'PM';
  final display = h % 12 == 0 ? 12 : h % 12;
  return '$display:${m.toString().padLeft(2, '0')} $suffix';
}

String spanLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
