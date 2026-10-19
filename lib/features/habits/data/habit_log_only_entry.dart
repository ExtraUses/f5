import 'dart:convert';

import 'package:streak/core/extensions/date_extensions.dart';

/// A single log entry for a habit marked as "Log Only / Exclude from
/// Analytics".
///
/// Lives in its own Hive box (`habit_log_only_entries`), separate from
/// [Habit.completions] so analytics queries can't accidentally include
/// them. The hybrid migration policy decided in Phase 4 clarifications:
///
///   * Habits converted to log-only keep their historical [Completion]
///     entries in `Habit.completions` (so the user doesn't lose data
///     on conversion). The [Habit.isLogOnly] flag excludes those
///     entries from analytics going forward.
///   * All NEW entries logged after conversion are written here as
///     [HabitLogOnlyEntry] records. They never reach `Habit.completions`.
///
/// The entity is intentionally minimal: just enough state to render a
/// timeline of "you logged this on that day" without polluting streak,
/// consistency, or completion-rate math.
class HabitLogOnlyEntry {
  HabitLogOnlyEntry({
    required this.id,
    required this.habitId,
    required this.loggedAt,
    this.count = 1,
    this.hour,
    this.minute,
    this.note,
  });

  /// UUID v4. Independent of [Habit.id] so the same habit can have
  /// many log entries across many days.
  final String id;

  /// Foreign key into [Habit.id]. The entry is cascade-deleted when
  /// the parent habit is hard-deleted (handled in `HabitsController`).
  final String habitId;

  /// Day the entry was logged for. Stored as a UTC ISO-8601 string
  /// so it round-trips through JSON backups losslessly. Resolved to
  /// local midnight on read via [day].
  final DateTime loggedAt;

  /// Numeric value when the habit is quantitative (e.g. 8 glasses of
  /// water, 30 minutes of reading). Defaults to 1 for binary habits.
  final double count;

  /// Hour-of-day (0–23) when the entry was logged. Optional — null
  /// means "sometime today" and renders without a time stamp.
  final int? hour;

  /// Minute-of-hour (0–59) when the entry was logged. Optional.
  final int? minute;

  /// Free-form note attached by the user. Capped at 500 chars by
  /// the editor sheet. May be null.
  final String? note;

  /// Calendar day of the entry, snapped to local midnight. Drives
  /// the per-day grouping in the log-only history view.
  DateTime get day => loggedAt.atMidnight;

  /// `YYYY-MM-DD` key matching [Habit.completions]'s key format so
  /// the log-only history view can reuse [parseDayKey] etc.
  String get dayKey => day.dayKey;

  HabitLogOnlyEntry copyWith({
    double? count,
    int? hour,
    int? minute,
    String? note,
    DateTime? loggedAt,
  }) =>
      HabitLogOnlyEntry(
        id: id,
        habitId: habitId,
        loggedAt: loggedAt ?? this.loggedAt,
        count: count ?? this.count,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'habitId': habitId,
        'loggedAt': loggedAt.toUtc().toIso8601String(),
        'count': count,
        if (hour != null) 'hour': hour,
        if (minute != null) 'minute': minute,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory HabitLogOnlyEntry.fromMap(Map<String, dynamic> map) =>
      HabitLogOnlyEntry(
        id: map['id'] as String,
        habitId: map['habitId'] as String,
        loggedAt:
            DateTime.tryParse((map['loggedAt'] ?? '') as String)?.toLocal() ??
                DateTime.now(),
        count: ((map['count'] ?? 1) as num).toDouble(),
        hour: map['hour'] as int?,
        minute: map['minute'] as int?,
        note: map['note'] is String ? map['note'] as String : null,
      );

  String toJson() => json.encode(toMap());

  factory HabitLogOnlyEntry.fromJson(String source) =>
      HabitLogOnlyEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
