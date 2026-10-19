import 'package:flutter/foundation.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/focus/data/focus_session.dart';

/// Rolling-window analytics for focus sessions.
///
/// Complementary to [FocusStats], which buckets sessions by calendar
/// week/month/year. [FocusTimeframeStats] instead uses a rolling N-day
/// window ending today (or since the very first session, when
/// [FocusTimeframe.allTime] is selected). The per-bucket breakdown is
/// always a daily series — every entry in [buckets] is a single day —
/// which makes the stacked-bar chart layer straightforward: each day's
/// bar is one [BarChartGroupData] whose segments are per-label totals.
///
/// Per-label color is **not** stored here. The chart widget resolves it
/// at render time via [FocusLabelsController.colorOf] so that a label
/// edit (color change) instantly reflects in past bars without
/// recomputation.
enum FocusTimeframe {
  /// Last 30 days, ending today (inclusive).
  last30Days(30),

  /// Last 90 days, ending today (inclusive).
  last90Days(90),

  /// Every session ever logged, with a daily series spanning the first
  /// session's start through today.
  allTime(0);

  const FocusTimeframe(this.days);

  /// Window length in days. Zero means "all time".
  final int days;
}

@immutable
class FocusTimeframeStats {
  const FocusTimeframeStats({
    required this.timeframe,
    required this.buckets,
    required this.series,
    required this.perLabel,
    required this.perLabelPerDay,
    required this.totalSeconds,
    required this.sessionCount,
    required this.activeDays,
    required this.windowStart,
    required this.windowEnd,
  });

  final FocusTimeframe timeframe;

  /// One [DateTime] per day in the window, ascending. For
  /// [FocusTimeframe.allTime] this can be hundreds of days long; the
  /// chart widget should aggregate further if needed.
  final List<DateTime> buckets;

  /// Total seconds per day, aligned with [buckets].
  final List<int> series;

  /// Total seconds per label id across the whole window. Includes the
  /// empty-string label id for sessions that had no label assigned
  /// (those render as a "uncategorized" fallback segment).
  final Map<String, int> perLabel;

  /// `labelId → dayIndex → seconds`. Used by the segmented stacked
  /// bar chart to draw each segment. Sparse: a label that was never
  /// used on a given day has no entry for that index.
  final Map<String, Map<int, int>> perLabelPerDay;

  final int totalSeconds;
  final int sessionCount;

  /// Number of distinct days in the window that had at least one
  /// session ≥ 30 seconds. Drives the consistency percentage.
  final int activeDays;

  /// Inclusive start (midnight) of the rolling window. Equal to
  /// [buckets.first] when buckets is non-empty.
  final DateTime windowStart;

  /// Inclusive end (midnight of today) of the rolling window.
  final DateTime windowEnd;

  /// Consistency = activeDays / totalDaysInWindow, as a percentage
  /// 0–100 (rounded). For [FocusTimeframe.allTime] the denominator is
  /// the count of days between the first session ever and today
  /// (inclusive), not the literal number of buckets — so a user who
  /// installed yesterday and focused once today has 1/2 = 50%.
  int get consistencyPercent {
    final denom = totalDaysInWindow;
    if (denom <= 0) return 0;
    return ((activeDays / denom) * 100).round().clamp(0, 100);
  }

  int get totalDaysInWindow {
    if (buckets.isEmpty) return 0;
    return windowEnd.difference(windowStart).inDays + 1;
  }

  /// Ranking of labels by total seconds, descending. Used to drive the
  /// per-label totals card on the Focus Stats screen.
  List<MapEntry<String, int>> get labelRanking {
    final entries = perLabel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  static FocusTimeframeStats compute({
    required List<FocusSession> sessions,
    required FocusTimeframe timeframe,
    required DateTime now,
    String? habitId,
  }) {
    final scoped = habitId == null
        ? sessions
        : sessions.where((s) => s.habitId == habitId).toList();

    final today = now.subtract(Duration(hours: AppClock.cutoffHour)).atMidnight;

    final DateTime windowStart;
    if (timeframe == FocusTimeframe.allTime) {
      if (scoped.isEmpty) {
        windowStart = today;
      } else {
        var earliest = scoped.first.countedOn;
        for (final s in scoped) {
          if (s.countedOn.isBefore(earliest)) earliest = s.countedOn;
        }
        windowStart = earliest.atMidnight;
      }
    } else {
      windowStart = today.subtract(Duration(days: timeframe.days - 1));
    }

    final windowEnd = today;
    final dayCount = windowEnd.difference(windowStart).inDays + 1;
    final buckets = [
      for (var i = 0; i < dayCount; i++) windowStart.addDays(i),
    ];
    final series = List<int>.filled(buckets.length, 0);
    final perLabel = <String, int>{};
    final perLabelPerDay = <String, Map<int, int>>{};

    final firstBucketEpoch = buckets.first.epochDay;
    var totalSeconds = 0;
    var sessionCount = 0;
    final activeDaysSet = <int>{};

    for (final session in scoped) {
      if (session.seconds < 30) continue;
      final day = session.countedOn;
      final epoch = day.epochDay;
      final index = epoch - firstBucketEpoch;
      if (index < 0 || index >= buckets.length) continue;
      sessionCount++;
      totalSeconds += session.seconds;
      series[index] += session.seconds;
      activeDaysSet.add(epoch);

      // Resolve the label id for this session — preferring the new
      // [FocusSession.labelId] when present, falling back to the
      // legacy free-form label string when not. The empty string is
      // the canonical "uncategorized" bucket.
      final labelId = session.labelId;
      perLabel[labelId] = (perLabel[labelId] ?? 0) + session.seconds;
      perLabelPerDay.putIfAbsent(labelId, () => {})[index] =
          (perLabelPerDay[labelId]?[index] ?? 0) + session.seconds;
    }

    return FocusTimeframeStats(
      timeframe: timeframe,
      buckets: buckets,
      series: series,
      perLabel: perLabel,
      perLabelPerDay: perLabelPerDay,
      totalSeconds: totalSeconds,
      sessionCount: sessionCount,
      activeDays: activeDaysSet.length,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }
}
