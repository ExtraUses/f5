import 'package:flutter/foundation.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/focus/data/focus_session.dart';

enum FocusRange { week, month, year }

@immutable
class FocusStats {
  const FocusStats({
    required this.todaySeconds,
    required this.weekSeconds,
    required this.monthSeconds,
    required this.totalSeconds,
    required this.sessionCount,
    required this.buckets,
    required this.series,
    required this.perHabit,
    required this.rangeCount,
    this.perLabel = const {},
  });

  final int todaySeconds;
  final int weekSeconds;
  final int monthSeconds;
  final int totalSeconds;
  final int sessionCount;
  final List<DateTime> buckets;
  final List<int> series;
  final Map<String, int> perHabit;
  final Map<String, int> perLabel;
  final int rangeCount;

  List<MapEntry<String, int>> get labelRanking =>
      (perLabel.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(8)
          .toList();

  int get averageSeconds =>
      sessionCount == 0 ? 0 : totalSeconds ~/ sessionCount;

  int get rangeSeconds => series.fold(0, (sum, value) => sum + value);

  int get bestBucket {
    var best = 0;
    for (var i = 1; i < series.length; i++) {
      if (series[i] > series[best]) best = i;
    }
    return best;
  }

  static List<DateTime> _bucketsFor(
    FocusRange range,
    DateTime today,
    int weekStart,
    int offset,
  ) {
    switch (range) {
      case FocusRange.week:
        final first = today.startOfWeek(weekStart).addDays(offset * 7);
        return [for (var i = 0; i < 7; i++) first.addDays(i)];
      case FocusRange.month:
        final anchor = DateTime(today.year, today.month + offset);
        final days = DateTime(anchor.year, anchor.month + 1, 0).day;
        return [
          for (var i = 1; i <= days; i++)
            DateTime(anchor.year, anchor.month, i),
        ];
      case FocusRange.year:
        final year = today.year + offset;
        return [for (var m = 1; m <= 12; m++) DateTime(year, m)];
    }
  }

  static FocusStats compute({
    required List<FocusSession> sessions,
    required FocusRange range,
    required DateTime now,
    required int weekStart,
    String? habitId,
    int offset = 0,
  }) {
    final scoped = habitId == null
        ? sessions
        : sessions.where((s) => s.habitId == habitId).toList();

    final today =
        now.subtract(Duration(hours: AppClock.cutoffHour)).atMidnight;
    final weekFrom = today.startOfWeek(weekStart);
    final buckets = _bucketsFor(range, today, weekStart, offset);
    final series = List<int>.filled(buckets.length, 0);
    final perHabit = <String, int>{};
    final perLabel = <String, int>{};

    final todayIndex = today.epochDay;
    final weekIndex = weekFrom.epochDay;
    final firstBucket = buckets.first.epochDay;
    final bucketYear = buckets.first.year;

    var rangeCount = 0;
    var todaySeconds = 0;
    var weekSeconds = 0;
    var monthSeconds = 0;
    var totalSeconds = 0;

    for (final session in scoped) {
      final day = session.countedOn;
      final epoch = day.epochDay;
      totalSeconds += session.seconds;
      if (epoch == todayIndex) todaySeconds += session.seconds;
      final weekOffset = epoch - weekIndex;
      if (weekOffset >= 0 && weekOffset < 7) weekSeconds += session.seconds;
      if (day.year == today.year && day.month == today.month) {
        monthSeconds += session.seconds;
      }

      final index = range == FocusRange.year
          ? (day.year == bucketYear ? day.month - 1 : -1)
          : epoch - firstBucket;
      if (index < 0 || index >= buckets.length) continue;
      rangeCount++;
      series[index] += session.seconds;
      perHabit[session.habitId] =
          (perHabit[session.habitId] ?? 0) + session.seconds;
      if (session.label.isNotEmpty) {
        perLabel[session.label] =
            (perLabel[session.label] ?? 0) + session.seconds;
      }
    }

    return FocusStats(
      todaySeconds: todaySeconds,
      weekSeconds: weekSeconds,
      monthSeconds: monthSeconds,
      totalSeconds: totalSeconds,
      sessionCount: scoped.length,
      buckets: buckets,
      series: series,
      perHabit: perHabit,
      perLabel: perLabel,
      rangeCount: rangeCount,
    );
  }
}
