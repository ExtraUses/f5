import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/color_extensions.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/extensions/inset_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/routing/app_navigator.dart';
import 'package:streak/core/widgets/app_empty_state.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_stats.dart';
import 'package:streak/features/focus/data/focus_timeframe_stats.dart';
import 'package:streak/features/focus/pages/express_focus_stats_page.dart';
import 'package:streak/features/focus/pages/focus_history_page.dart';
import 'package:streak/features/focus/pages/minimal_focus_stats_page.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/state/focus_labels_controller.dart';
import 'package:streak/features/focus/widgets/color_coded_focus_bars.dart';
import 'package:streak/features/focus/widgets/consistency_radial_gauge.dart';
import 'package:streak/features/focus/widgets/focus_heatmap.dart';
import 'package:streak/features/focus/widgets/focus_period_bar.dart';
import 'package:streak/features/focus/widgets/graph_color_override_button.dart';
import 'package:streak/features/focus/widgets/productive_hours_chart.dart';
import 'package:streak/features/focus/widgets/segmented_label_bar_chart.dart';
import 'package:streak/features/focus/widgets/timeframe_filter_chip_bar.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/state/graph_color_overrides_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';
import 'package:streak/features/statistics/widgets/stat_charts.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

class FocusStatsPage extends StatefulWidget {
  const FocusStatsPage({super.key, this.habitId});

  final String? habitId;

  @override
  State<FocusStatsPage> createState() => _FocusStatsPageState();
}

class _FocusStatsPageState extends State<FocusStatsPage> {
  FocusRange _range = FocusRange.week;
  int _offset = 0;

  /// When non-null, the page is in "rolling-window" mode and every
  /// analytical widget on the screen recalculates against this
  /// timeframe. When null, the legacy week/month/year view is used.
  FocusTimeframe? _timeframe;

  List<({String name, Color color, int count})> _ranking(
    FocusStats stats,
    HabitsController habits,
    Color accent,
  ) {
    final entries = [
      for (final entry in stats.perHabit.entries)
        (
          name: habits.byId(entry.key)?.name ?? context.l10n.focus_free_session,
          color: habits.byId(entry.key)?.color.shownIn(context) ?? accent,
          count: entry.value,
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return entries.take(8).toList();
  }

  /// Per-label ranking built from a [FocusTimeframeStats] — each label's
  /// color is resolved through [FocusLabelsController.colorOf] so the
  /// ranking chips visually match the segments in the stacked bar chart.
  List<({String name, Color color, int count})> _labelRanking(
    FocusTimeframeStats tfStats,
    FocusLabelsController labels,
    Color accent,
  ) {
    final entries = <({String name, Color color, int count})>[];
    for (final entry in tfStats.labelRanking) {
      final name = labels.nameOf(entry.key);
      entries.add((
        name: name.isEmpty ? context.l10n.focus_free_session : name,
        color: labels.colorOf(entry.key, fallback: accent),
        count: entry.value,
      ));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    if (settings.isExpressStyle) {
      return ExpressFocusStatsPage(habitId: widget.habitId);
    }
    if (settings.isMinimalStyle) {
      return MinimalFocusStatsPage(habitId: widget.habitId);
    }

    context.select<FocusController, int>((f) => f.revision);
    final focus = context.read<FocusController>();
    final habits = context.watch<HabitsController>();
    final labels = context.watch<FocusLabelsController>();
    final overrides = context.watch<GraphColorOverridesController>();
    final habit = widget.habitId == null ? null : habits.byId(widget.habitId!);
    final accent = habit?.color.shownIn(context) ?? context.colors.primary;

    final stats = FocusStats.compute(
      sessions: focus.sessions,
      range: _range,
      now: AppClock.now(),
      weekStart: settings.weekStart,
      habitId: widget.habitId,
      offset: _offset,
    );

    // When a rolling-window timeframe is active, also compute the
    // timeframe-scoped stats that drive the new analytical widgets.
    final tfStats = _timeframe == null
        ? null
        : FocusTimeframeStats.compute(
            sessions: focus.sessions,
            timeframe: _timeframe!,
            now: AppClock.now(),
            habitId: widget.habitId,
          );

    final title = habit?.name ?? context.l10n.focus_stats;
    final hasSessions = stats.sessionCount > 0 ||
        (tfStats != null && tfStats.sessionCount > 0);

    final body = !hasSessions
        ? AppEmptyState(
            icon: LucideIcons.timer,
            title: context.l10n.no_data_yet,
            message: context.l10n.focus_history_empty_sub,
          )
        : ListView(
            padding: context.pagePadding(16, 8, 16, 28),
            children: [
              // ─── Rolling-window filter bar ─────────────────────────
              // Visible in every mode; selecting a timeframe shifts every
              // chart below to the rolling-window series.
              StatReveal(
                child: TimeframeFilterChipBar(
                  selected: _timeframe,
                  onChanged: (tf) => setState(() {
                    _timeframe = tf;
                    // Reset the legacy offset so when the user drops back
                    // out of timeframe mode they start at "this week"
                    // rather than wherever they last scrolled to.
                    _offset = 0;
                  }),
                  accent: accent,
                ),
              ),
              const SizedBox(height: 16),

              // ─── Consistency radial gauge (only in timeframe mode) ─
              if (_timeframe != null && tfStats != null) ...[
                StatReveal(
                  child: StatCard(
                    title: context.l10n.focus_consistency,
                    icon: LucideIcons.target,
                    color: accent,
                    trailing: GraphColorOverrideButton(
                      graphId:
                          GraphColorOverridesController.focusConsistencyGauge,
                      defaultColor: accent,
                    ),
                    child: Center(
                      child: ConsistencyRadialGauge(
                        stats: tfStats,
                        accent: overrides.resolve(
                          GraphColorOverridesController.focusConsistencyGauge,
                          accent,
                        ),
                        colorOverride: overrides.overrideFor(
                          GraphColorOverridesController.focusConsistencyGauge,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─── Time totals (always shown) ────────────────────────
              StatReveal(
                child: StatPair(
                  left: MiniStat(
                    icon: LucideIcons.sun,
                    color: accent,
                    value: formatHoursShort(stats.todaySeconds),
                    label: context.l10n.today,
                  ),
                  right: MiniStat(
                    icon: LucideIcons.calendarDays,
                    color: context.tokens.info,
                    value: formatHoursShort(stats.weekSeconds),
                    label: context.l10n.week,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StatReveal(
                child: StatPair(
                  left: MiniStat(
                    icon: LucideIcons.calendarRange,
                    color: context.tokens.warning,
                    value: formatHoursShort(stats.monthSeconds),
                    label: context.l10n.month,
                  ),
                  right: MiniStat(
                    icon: LucideIcons.timer,
                    color: context.tokens.success,
                    value: formatHoursShort(stats.totalSeconds),
                    label: context.l10n.total,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StatReveal(
                child: StatPair(
                  left: MiniStat(
                    icon: LucideIcons.circlePlay,
                    color: accent,
                    value: '${stats.sessionCount}',
                    label: context.l10n.focus_sessions,
                  ),
                  right: MiniStat(
                    icon: LucideIcons.activity,
                    color: context.tokens.info,
                    value: formatHoursShort(stats.averageSeconds),
                    label: context.l10n.focus_average,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Main bar chart card ───────────────────────────────
              // In timeframe mode, render the new segmented stacked bar
              // chart. In legacy mode, render the existing single-tone
              // FocusRangeBars with the week/month/year segmented control.
              StatReveal(
                child: StatCard(
                  title: _timeframe != null
                      ? context.l10n.focus_graph_distribution
                      : context.l10n.focus_total,
                  icon: LucideIcons.chartColumn,
                  color: accent,
                  trailing: GraphColorOverrideButton(
                    graphId: _timeframe != null
                        ? GraphColorOverridesController.focusSegmentedBars
                        : GraphColorOverridesController.focusRangeBars,
                    defaultColor: accent,
                  ),
                  child: _timeframe != null && tfStats != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _timeframeWindowTitle(tfStats),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: sheetLabelStyle(context, size: 12.5),
                            ),
                            const SizedBox(height: 12),
                            SegmentedLabelBarChart(
                              stats: tfStats,
                              fallbackColor: overrides.resolve(
                                GraphColorOverridesController.focusSegmentedBars,
                                accent,
                              ),
                              colorOverride: overrides.overrideFor(
                                GraphColorOverridesController.focusSegmentedBars,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Segmented(
                                options: [
                                  context.l10n.week,
                                  context.l10n.month,
                                  context.l10n.year,
                                ],
                                index: FocusRange.values.indexOf(_range),
                                onChanged: (index) => setState(() {
                                  _range = FocusRange.values[index];
                                  _offset = 0;
                                }),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FocusPeriodBar(
                              range: _range,
                              offset: _offset,
                              stats: stats,
                              accent: accent,
                              onOffset: (value) =>
                                  setState(() => _offset = value),
                            ),
                            const SizedBox(height: 14),
                            ColorCodedFocusBars(
                              stats: stats,
                              sessions: focus.sessions,
                              range: _range,
                              color: overrides.resolve(
                                GraphColorOverridesController.focusRangeBars,
                                accent,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // ─── Productive Hours (24-hour timeline) ───────────────
              // Only shown when a timeframe filter is active, since the
              // chart needs the rolling-window sessions.
              if (_timeframe != null) ...[
                const SizedBox(height: 16),
                StatReveal(
                  child: StatCard(
                    title: context.l10n.focus_productive_hours,
                    icon: LucideIcons.clock,
                    color: accent,
                    child: ProductiveHoursChart(
                      timeframe: _timeframe!,
                      accent: accent,
                    ),
                  ),
                ),
              ],

              // ─── Focus Intensity Heatmap ────────────────────────────
              // Always visible — shows the last ~53 weeks of focus
              // activity with scaled color brightness.
              const SizedBox(height: 16),
              StatReveal(
                child: StatCard(
                  title: context.l10n.focus_heatmap,
                  icon: LucideIcons.calendarDays,
                  color: accent,
                  child: FocusHeatmap(
                    accent: overrides.resolve(
                      GraphColorOverridesController.focusLabelTotals,
                      accent,
                    ),
                  ),
                ),
              ),

              // ─── Per-label ranking / distribution ──────────────────
              // In timeframe mode, the label ranking uses the new
              // per-label totals and each row's color matches the label's
              // assigned color (so the legend visually matches the
              // stacked bar chart's segments).
              if (_timeframe != null &&
                  tfStats != null &&
                  tfStats.perLabel.isNotEmpty) ...[
                const SizedBox(height: 16),
                StatReveal(
                  child: StatCard(
                    title: context.l10n.by_label,
                    icon: LucideIcons.tag,
                    color: accent,
                    trailing: GraphColorOverrideButton(
                      graphId:
                          GraphColorOverridesController.focusLabelTotals,
                      defaultColor: accent,
                    ),
                    child: HabitRanking(
                      entries: _labelRanking(tfStats, labels, accent),
                      format: formatHoursShort,
                    ),
                  ),
                ),
              ] else if (_timeframe == null &&
                  widget.habitId == null &&
                  stats.perHabit.length > 1) ...[
                const SizedBox(height: 16),
                StatReveal(
                  child: StatCard(
                    title: context.l10n.by_habit,
                    icon: LucideIcons.listOrdered,
                    color: accent,
                    child: HabitRanking(
                      entries: _ranking(stats, habits, accent),
                      format: formatHoursShort,
                    ),
                  ),
                ),
              ] else if (_timeframe == null &&
                  stats.perLabel.isNotEmpty) ...[
                const SizedBox(height: 16),
                StatReveal(
                  child: StatCard(
                    title: context.l10n.by_label,
                    icon: LucideIcons.tag,
                    color: accent,
                    child: HabitRanking(
                      entries: [
                        for (final entry in stats.labelRanking)
                          (name: entry.key, color: accent, count: entry.value),
                      ],
                      format: formatHoursShort,
                    ),
                  ),
                ),
              ],
            ],
          );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => AppNavigator.pop(),
        ),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: context.l10n.focus_history,
            icon: const Icon(LucideIcons.history),
            onPressed: () => AppNavigator.push(
              FocusHistoryPage(habitId: widget.habitId),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  /// Human-readable window label for the timeframe card header —
  /// e.g. "Last 30 days · Aug 19 → Sep 17".
  String _timeframeWindowTitle(FocusTimeframeStats tfStats) {
    String fmt(DateTime d) => '${d.month}/${d.day}';
    final rangeLabel = _timeframe == FocusTimeframe.allTime
        ? context.l10n.focus_timeframe_all
        : _timeframe == FocusTimeframe.last90Days
        ? context.l10n.focus_timeframe_90d
        : context.l10n.focus_timeframe_30d;
    return '$rangeLabel  ·  ${fmt(tfStats.windowStart)} → ${fmt(tfStats.windowEnd)}';
  }
}
