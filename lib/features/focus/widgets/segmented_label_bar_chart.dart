import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/features/focus/data/focus_timeframe_stats.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_labels_controller.dart';
import 'package:streak/features/statistics/widgets/stat_axis.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

/// Vertical stacked bar chart where each bar represents one day in the
/// active [FocusTimeframeStats] window, and each segment within a bar
/// represents the time spent on a single Focus Label.
///
/// Each segment's color is pulled dynamically from its assigned
/// [FocusLabel.color] via [FocusLabelsController.colorOf]. If a label
/// was deleted after the session was logged, the segment falls back to
/// the surface-on-surface muted color so the chart remains drawable.
///
/// The chart uses fl_chart's stacked bar support — one [BarChartRodData]
/// per day, with a list of [BarChartRodStackItem]s sorted by total
/// descending so the largest label paints at the bottom of each stack
/// (visual anchor for the eye when comparing days).
class SegmentedLabelBarChart extends StatelessWidget {
  const SegmentedLabelBarChart({
    super.key,
    required this.stats,
    required this.fallbackColor,
    this.height = 180,
    this.colorOverride,
    this.maxBars = 35,
  });

  final FocusTimeframeStats stats;
  final Color fallbackColor;

  /// Optional manual color override applied to the entire chart. When
  /// null, the chart paints each segment with its label's color (the
  /// intended default). When non-null, the override wins for every
  /// segment — this is the hook used by [GraphColorOverrideButton].
  final Color? colorOverride;

  final double height;

  /// Maximum number of bars to render. When the window has more days
  /// than this (e.g. all-time with 200+ days), the chart aggregates
  /// by collapsing N adjacent days into a single composite bar.
  final int maxBars;

  @override
  Widget build(BuildContext context) {
    if (stats.buckets.isEmpty || stats.totalSeconds == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '—',
            style: statLabel(context),
          ),
        ),
      );
    }

    final labels = context.watch<FocusLabelsController>();
    // Build the set of label ids that appear in the window, ordered by
    // total descending so the legend reads naturally.
    final rankedLabelIds = stats.labelRanking.map((e) => e.key).toList();
    // Resolve a stable color per label id. The map is rebuilt on every
    // rebuild so label edits (color change) reflect immediately.
    final colorFor = <String, Color>{
      for (final id in rankedLabelIds)
        id: colorOverride ?? labels.colorOf(id, fallback: fallbackColor),
    };

    // If the window has more days than [maxBars], aggregate into a
    // virtual series by collapsing adjacent buckets.
    final aggregateBy = stats.buckets.length > maxBars
        ? (stats.buckets.length / maxBars).ceil()
        : 1;

    final aggregated = _aggregate(aggregateBy);
    final values = aggregated.totals;
    final labelStacks = aggregated.stacks;

    final maxYValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final scale = axisScale(maxYValue, lines: 3, headroom: 0.12);

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
                if (dayIndex < 0 || dayIndex >= aggregated.buckets.length) {
                  return null;
                }
                final total = rod.toY * 60;
                final buffer = StringBuffer(
                  formatHoursShort(total.round()),
                );
                // Show the top 3 contributing labels under the total.
                final stackForDay = labelStacks[dayIndex];
                final sorted = stackForDay.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                for (final entry in sorted.take(3)) {
                  final name = labels.nameOf(entry.key);
                  if (name.isEmpty) continue;
                  buffer.write('\n$name  ${formatHoursShort(entry.value * 60)}');
                }
                return BarTooltipItem(
                  buffer.toString(),
                  TextStyle(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.4,
                  ),
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
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barGroups: [
            for (var i = 0; i < aggregated.buckets.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: colorOverride ?? fallbackColor,
                    width: _barWidthFor(aggregated.buckets.length),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_barWidthFor(aggregated.buckets.length) / 2),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: scale.maxY,
                      color: context.colors.surfaceContainerHighest
                          .withValues(alpha: 0.22),
                    ),
                    rodStackItems: colorOverride == null
                        ? _stackItemsFor(labelStacks[i], colorFor)
                        : const [],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  double _barWidthFor(int count) {
    if (count <= 7) return 14;
    if (count <= 30) return 6;
    if (count <= 90) return 3;
    return 2;
  }

  /// Build a list of [BarChartRodStackItem] for a single day's bar,
  /// sorted by total descending so the largest label paints at the
  /// bottom.
  List<BarChartRodStackItem> _stackItemsFor(
    Map<String, int> dayStack,
    Map<String, Color> colorFor,
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
      // fl_chart 0.69 BarChartRodStackItem takes 3 POSITIONAL args:
      // (fromY, toY, color) — NOT named parameters.
      items.add(
        BarChartRodStackItem(
          fromY,
          toY,
          colorFor[entry.key] ?? fallbackColor,
        ),
      );
      fromY = toY;
    }
    return items;
  }

  /// Aggregates the per-day stats into N-day composite buckets when the
  /// raw day count exceeds [maxBars]. Returns a triple of (buckets,
  /// per-bucket totals in minutes, per-bucket per-label totals in
  /// seconds).
  _Aggregated _aggregate(int groupSize) {
    if (groupSize <= 1) {
      return _Aggregated(
        buckets: stats.buckets,
        totals: [for (final s in stats.series) s / 60.0],
        stacks: [
          for (var i = 0; i < stats.series.length; i++)
            _dayStack(i),
        ],
      );
    }
    final buckets = <DateTime>[];
    final totals = <double>[];
    final stacks = <Map<String, int>>[];
    for (var i = 0; i < stats.buckets.length; i += groupSize) {
      var sum = 0;
      final stack = <String, int>{};
      for (var j = i; j < i + groupSize && j < stats.buckets.length; j++) {
        sum += stats.series[j];
        final dayStack = _dayStack(j);
        for (final entry in dayStack.entries) {
          stack[entry.key] = (stack[entry.key] ?? 0) + entry.value;
        }
      }
      buckets.add(stats.buckets[i]);
      totals.add(sum / 60.0);
      stacks.add(stack);
    }
    return _Aggregated(buckets: buckets, totals: totals, stacks: stacks);
  }

  Map<String, int> _dayStack(int dayIndex) {
    final out = <String, int>{};
    for (final entry in stats.perLabelPerDay.entries) {
      final seconds = entry.value[dayIndex];
      if (seconds != null && seconds > 0) {
        out[entry.key] = seconds;
      }
    }
    return out;
  }
}

class _Aggregated {
  const _Aggregated({
    required this.buckets,
    required this.totals,
    required this.stacks,
  });

  final List<DateTime> buckets;
  final List<double> totals;
  final List<Map<String, int>> stacks;
}
