import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_timeframe_stats.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/state/focus_labels_controller.dart';

/// 24-hour horizontal distribution chart showing when focus activity
/// happens throughout the day.
///
/// Each of the 24 hour blocks (12 AM to 11 PM) is rendered as a
/// vertical bar. The bar's color is determined by the dominant label
/// during that hour — if multiple labels were active, the bar is split
/// proportionally. The opacity scales with usage: a few minutes of
/// focus = dim bar, a full hour = vivid bar.
///
/// The chart respects the active [FocusTimeframe] — when the user
/// selects 30D / 90D / All Time on the Focus Stats page, this chart
/// aggregates sessions across that window.
class ProductiveHoursChart extends StatelessWidget {
  const ProductiveHoursChart({
    super.key,
    required this.timeframe,
    this.height = 120,
    this.accent,
  });

  final FocusTimeframe timeframe;
  final double height;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final labels = context.watch<FocusLabelsController>();
    final scheme = context.colors;

    // Compute per-hour totals across the timeframe window.
    final now = DateTime.now();
    final windowStart = timeframe == FocusTimeframe.allTime
        ? _earliestSession(focus.sessions, now)
        : now.subtract(Duration(days: timeframe.days - 1));

    final hourBuckets = _computeHourBuckets(focus.sessions, windowStart, now);

    // Find the max total in any hour for scaling.
    final maxTotal = hourBuckets.fold<int>(0, (max, b) => b.totalSeconds > max ? b.totalSeconds : max);
    final scale = maxTotal <= 0 ? 1.0 : 3600.0 / maxTotal; // 1 hour = full height

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Label row.
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              context.l10n.focus_productive_hours,
              style: sheetLabelStyle(
                context,
                size: 13,
                color: context.tokens.muted,
              ),
            ),
          ),
          // The 24-hour bar strip.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = (constraints.maxWidth - 23 * 2) / 24;
                return Row(
                  children: [
                    for (var h = 0; h < 24; h++)
                      Expanded(
                        child: _HourBlock(
                          hour: h,
                          bucket: hourBuckets[h],
                          labels: labels,
                          accent: accent ?? scheme.primary,
                          scale: scale,
                          barWidth: barWidth,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Hour labels (every 6 hours).
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in [0, 6, 12, 18, 23])
                Text(
                  _hourLabel(h),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.muted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  DateTime _earliestSession(List<FocusSession> sessions, DateTime now) {
    if (sessions.isEmpty) return now;
    var earliest = sessions.first.startedAt;
    for (final s in sessions) {
      if (s.startedAt.isBefore(earliest)) earliest = s.startedAt;
    }
    return earliest;
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12a';
    if (hour < 12) return '${hour}a';
    if (hour == 12) return '12p';
    return '${hour - 12}p';
  }

  List<_HourBucket> _computeHourBuckets(
    List<FocusSession> sessions,
    DateTime windowStart,
    DateTime now,
  ) {
    final buckets = List<_HourBucket>.generate(24, (h) => _HourBucket(hour: h));
    for (final session in sessions) {
      if (session.seconds < 30) continue;
      final start = session.startedAt;
      if (start.isBefore(windowStart)) continue;
      if (start.isAfter(now)) continue;

      // Distribute session seconds across the hours it spans.
      var remaining = session.seconds;
      var cursor = start;
      final labelId = session.labelId;
      while (remaining > 0 && cursor.isBefore(now)) {
        final hour = cursor.hour;
        final nextHour = DateTime(cursor.year, cursor.month, cursor.day, hour + 1);
        final span = math.min(remaining, nextHour.difference(cursor).inSeconds);
        if (span > 0) {
          buckets[hour].add(labelId, span);
        }
        remaining -= span;
        cursor = nextHour;
      }
    }
    return buckets;
  }
}

class _HourBucket {
  _HourBucket({required this.hour});

  final int hour;
  int totalSeconds = 0;
  final Map<String, int> perLabel = {};

  void add(String labelId, int seconds) {
    totalSeconds += seconds;
    perLabel[labelId] = (perLabel[labelId] ?? 0) + seconds;
  }

  List<MapEntry<String, int>> get sortedLabels =>
      (perLabel.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
}

class _HourBlock extends StatelessWidget {
  const _HourBlock({
    required this.hour,
    required this.bucket,
    required this.labels,
    required this.accent,
    required this.scale,
    required this.barWidth,
  });

  final int hour;
  final _HourBucket bucket;
  final FocusLabelsController labels;
  final Color accent;
  final double scale;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    if (bucket.totalSeconds <= 0) {
      // Empty hour — render a faint track.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: barWidth,
            height: 3,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    // Build the stacked segments for this hour.
    final sorted = bucket.sortedLabels;
    final segments = <_Segment>[];
    var fromY = 0.0;
    for (final entry in sorted) {
      final fraction = entry.value / bucket.totalSeconds;
      final heightFraction = (entry.value / 3600.0).clamp(0.0, 1.0) * scale.clamp(0.0, 1.0);
      segments.add(_Segment(
        color: labels.colorOf(entry.key, fallback: accent),
        fromY: fromY,
        toY: fromY + heightFraction,
        fraction: fraction,
      ));
      fromY += heightFraction;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Tooltip(
          message: _tooltipText,
          child: SizedBox(
            width: barWidth,
            height: (fromY * 80).clamp(3.0, 80.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final seg in segments.reversed)
                    Expanded(
                      flex: (seg.fraction * 100).round().clamp(1, 100),
                      child: Container(color: seg.color),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _tooltipText {
    final parts = <String>[];
    parts.add('${_hourLabel(hour)}: ${_formatDuration(bucket.totalSeconds)}');
    final sortedLabels = bucket.sortedLabels;
    for (final entry in sortedLabels.take(3)) {
      final name = labels.nameOf(entry.key);
      if (name.isEmpty) continue;
      parts.add('$name: ${_formatDuration(entry.value)}');
    }
    return parts.join('\n');
  }

  String _hourLabel(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }
}

class _Segment {
  const _Segment({
    required this.color,
    required this.fromY,
    required this.toY,
    required this.fraction,
  });

  final Color color;
  final double fromY;
  final double toY;
  final double fraction;
}
