import 'dart:math';

import 'package:streak/core/extensions/date_extensions.dart';

class FocusSession {
  const FocusSession({
    required this.id,
    required this.habitId,
    required this.targetMinutes,
    required this.seconds,
    required this.completed,
    required this.startedAt,
    this.counted = false,
    this.label = '',
    this.labelId = '',
    this.linkedHabitIds = const [],
  });

  final String id;

  /// Soft-deprecated. Retained for backward compatibility with backups
  /// produced before v2.4.0. New code writes the empty string here and
  /// uses [labelId] for the primary activity tag. Legacy sessions are
  /// migrated to the auto-created `free-session` label by
  /// [FocusLabelsController.migrateLegacy]. Reads of analytics fall back
  /// to this field only when [labelId] is empty.
  final String habitId;

  final int targetMinutes;
  final int seconds;
  final bool completed;
  final DateTime startedAt;
  final bool counted;

  /// Legacy free-form label string. Still written for compatibility with
  /// older backups and the Android widget payload, but the canonical
  /// identity lives in [labelId].
  final String label;

  /// Foreign key into [FocusLabel.id]. Empty string means "uncategorized";
  /// the migration assigns `free-session` to legacy rows whose [habitId]
  /// was empty.
  final String labelId;

  /// Optional secondary habit links for multi-habit tagging (Phase 2).
  /// Writing to this list does NOT mutate [labelId].
  final List<String> linkedHabitIds;

  int get minutes => seconds ~/ 60;

  DateTime get countedOn => startedAt
      .add(Duration(seconds: seconds > 0 ? seconds - 1 : 0))
      .subtract(Duration(hours: AppClock.cutoffHour));

  List<FocusSession> split() {
    final pieces = <FocusSession>[];
    var start = startedAt.toLocal();
    var left = seconds;
    while (left > 0) {
      final gap = dayBorderAfter(start).difference(start).inMilliseconds;
      final span = max(1, (gap / 1000).ceil());
      if (span >= left) {
        pieces.add(_pieceOf(pieces.length + 1, start, left, last: true));
        break;
      }
      pieces.add(_pieceOf(pieces.length + 1, start, span));
      start = start.add(Duration(seconds: span));
      left -= span;
    }
    if (pieces.length < 2 || pieces.any((piece) => piece.seconds < 60)) {
      return [this];
    }
    return pieces;
  }

  FocusSession _pieceOf(int index, DateTime start, int span,
          {bool last = false}) =>
      FocusSession(
        id: index == 1 ? id : '$id-$index',
        habitId: habitId,
        targetMinutes: targetMinutes,
        seconds: span,
        completed: completed && last,
        startedAt: start,
        counted: counted,
        label: label,
        labelId: labelId,
        linkedHabitIds: linkedHabitIds,
      );

  FocusSession get asCounted => FocusSession(
        id: id,
        habitId: habitId,
        targetMinutes: targetMinutes,
        seconds: seconds,
        completed: completed,
        startedAt: startedAt,
        counted: true,
        label: label,
        labelId: labelId,
        linkedHabitIds: linkedHabitIds,
      );

  FocusSession copyWith({
    String? habitId,
    int? targetMinutes,
    int? seconds,
    bool? completed,
    DateTime? startedAt,
    bool? counted,
    String? label,
    String? labelId,
    List<String>? linkedHabitIds,
  }) =>
      FocusSession(
        id: id,
        habitId: habitId ?? this.habitId,
        targetMinutes: targetMinutes ?? this.targetMinutes,
        seconds: seconds ?? this.seconds,
        completed: completed ?? this.completed,
        startedAt: startedAt ?? this.startedAt,
        counted: counted ?? this.counted,
        label: label ?? this.label,
        labelId: labelId ?? this.labelId,
        linkedHabitIds: linkedHabitIds ?? this.linkedHabitIds,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'habitId': habitId,
        'targetMinutes': targetMinutes,
        'seconds': seconds,
        'completed': completed,
        'startedAt': startedAt.toIso8601String(),
        if (counted) 'counted': true,
        if (label.isNotEmpty) 'label': label,
        if (labelId.isNotEmpty) 'labelId': labelId,
        if (linkedHabitIds.isNotEmpty) 'linkedHabitIds': linkedHabitIds,
      };

  factory FocusSession.fromMap(Map<String, dynamic> map) => FocusSession(
        id: map['id'] as String,
        habitId: (map['habitId'] ?? '') as String,
        targetMinutes: ((map['targetMinutes'] ?? 0) as num).toInt(),
        seconds: ((map['seconds'] ?? 0) as num).toInt(),
        completed: (map['completed'] ?? false) as bool,
        startedAt: DateTime.tryParse((map['startedAt'] ?? '') as String) ??
            DateTime.now(),
        counted: map['counted'] == true,
        label: map['label'] is String ? map['label'] as String : '',
        labelId: map['labelId'] is String ? map['labelId'] as String : '',
        linkedHabitIds: map['linkedHabitIds'] is List
            ? List<String>.from(map['linkedHabitIds'] as List)
            : const [],
      );
}

DateTime dayBorderAfter(DateTime moment) {
  final day = moment
      .subtract(Duration(hours: AppClock.cutoffHour))
      .atMidnight
      .addDays(1);
  return DateTime(day.year, day.month, day.day, AppClock.cutoffHour);
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
}

String formatHoursShort(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0 && m == 0) return '${seconds}s';
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
