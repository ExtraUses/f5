import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/date_labels.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_stats.dart';
import 'package:streak/features/focus/state/focus_labels_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/statistics/widgets/stat_axis.dart';

/// Color-coordinated bar chart for the Focus Stats week/month/year view.
///
/// Replaces [FocusRangeBars] with a stacked bar chart where each day's bar
/// is split into segments colored by the focus label that was active during
/// that day's sessions. This gives the user an at-a-glance breakdown of
/// which labels contributed to each day's total — matching the Goodtime
/// history visualization.
class ColorCodedFocusBars extends StatelessWidget {
  const ColorCodedFocusBars({
    super.key,
    required this.stats,
    required this.sessions,
    required this.range,
    required this.color,
    this.height = 150,
  });

  final FocusStats stats;
  final List<FocusSession> sessions;
  final FocusRange range;
  final Color color;
  final double height;

  double get _barWidth => switch (range) {
        FocusRange.week => 14,
        FocusRange.month => 5,
        FocusRange.year => 11,
      };

  String _label(BuildContext context, int index) {
    if (index < 0 || index >= stats.buckets.length) return '';
    final locale = Localizations.localeOf(context);
    switch (range) {
      case FocusRange.week:
        return WeekdayLabels.narrowFrom(
          locale.languageCode,
          context.read<SettingsController>().weekStart,
        )[index];
      case FocusRange.month:
        final day = index + 1;
        return day == 1 || day % 5 == 0 ? '$day' : '';
      case FocusRange.year:
        return index.isEven
            ? DateFormat.MMM(locale.toString()).format(stats.buckets[index])
            : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<FocusLabelsController>();

    // Build per-day-per-label stacks from raw sessions.
    final stacks = _buildStacks();

    final values = [for (final s in stats.series) s / 60.0];
    final maxV = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final scale = axisScale(maxV, lines: 3, headroom: 0.12);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: scale.maxY,
          gridData: axisGrid(context, scale.step, top: scale.top),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  context.colors.surfaceContainerHighest,
              getTooltipItem: (group, _, rod, __) {
                final dayIndex = group.x;
                if (dayIndex < 0 || dayIndex >= stacks.length) return null;
                final total = rod.toY * 60;
                final dayStack = stacks[dayIndex];
                final sorted = dayStack.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return BarTooltipItem(
                  formatHoursShort(total.round()),
                  TextStyle(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  children: [
                    for (final entry in sorted.take(5)) ...[
                      TextSpan(
                        text: '\n',
                        style: const TextStyle(fontSize: 4),
                      ),
                      TextSpan(
                        text: '\u25CF  ',
                        style: TextStyle(
                          color: labels.colorOf(entry.key, fallback: color),
                          fontSize: 10,
                        ),
                      ),
                      TextSpan(
                        text:
                            '${labels.nameOf(entry.key)}  ${formatHoursShort(entry.value * 60)}',
                        style: TextStyle(
                          color: labels.colorOf(entry.key, fallback: color),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: axisLeftTitles(
              context,
              interval: scale.step,
              top: scale.top,
              format: (value) => formatHoursShort((value * 60).round()),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _label(context, value.toInt()),
                    textScaler: axisTextScaler(context),
                    style: TextStyle(
                      color: context.tokens.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: color,
                    width: _barWidth,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_barWidth / 2),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: scale.maxY,
                      color: context.colors.surfaceContainerHighest
                          .withValues(alpha: 0.22),
                    ),
                    rodStackItems: _stackItemsFor(
                      stacks[i],
                      labels,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Build per-day-per-label breakdown from raw sessions.
  /// Returns a list (one per bucket) of maps (labelId → seconds).
  List<Map<String, int>> _buildStacks() {
    final firstBucketEpoch = stats.buckets.first.epochDay;
    final result = List<Map<String, int>>.generate(
      stats.buckets.length,
      (_) => <String, int>{},
    );
    for (final session in sessions) {
      if (session.seconds < 30) continue;
      final day = session.countedOn;
      final index = range == FocusRange.year
          ? (day.year == stats.buckets.first.year ? day.month - 1 : -1)
          : day.epochDay - firstBucketEpoch;
      if (index < 0 || index >= result.length) continue;
      final labelId = session.labelId;
      result[index][labelId] =
          (result[index][labelId] ?? 0) + session.seconds;
    }
    return result;
  }

  /// Build [BarChartRodStackItem]s for a single day's bar, sorted by
  /// total descending so the largest label paints at the bottom.
  List<BarChartRodStackItem> _stackItemsFor(
    Map<String, int> dayStack,
    FocusLabelsController labels,
  ) {
    if (dayStack.isEmpty) return const [];
    final entries = dayStack.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final items = <BarChartRodStackItem>[];
    var fromY = 0.0;
    for (final entry in entries) {
      final seconds = entry.value;
      if (seconds <= 0) continue;
      final toY = fromY + seconds / 60;
      items.add(
        BarChartRodStackItem(
          fromY,
          toY,
          labels.colorOf(entry.key, fallback: color),
        ),
      );
      fromY = toY;
    }
    return items;
  }
}
