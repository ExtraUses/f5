import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/statistics/widgets/express_line_chart.dart';
import 'package:streak/features/statistics/widgets/stat_line_charts.dart';
import 'package:streak/core/extensions/color_extensions.dart';

class FocusDailyBars extends StatelessWidget {
  const FocusDailyBars({super.key, required this.habit, this.days = 14});

  final Habit habit;
  final int days;

  @override
  Widget build(BuildContext context) {
    final express = context.watch<SettingsController>().isExpressStyle;
    context.select<FocusController, int>((f) => f.revision);
    final focus = context.read<FocusController>();
    final span = express ? 30 : days;
    final today = AppClock.today();
    final start = today.addDays(1 - span);
    final minutes = [
      for (var i = 0; i < span; i++)
        focus.secondsForHabitOnDay(habit.id, start.addDays(i)) / 60,
    ];
    String label(double value) => formatHoursShort((value * 60).round());
    String axis(double value) => value <= 0 ? '0' : label(value);

    if (express) {
      final locale = Localizations.localeOf(context).toString();
      final month = DateFormat.MMM(locale);
      return ExpressLineChart(
        values: minutes,
        color: habit.color.shownIn(context),
        window: 10,
        height: 176,
        format: label,
        axisFormat: axis,
        label: (index) => '${start.addDays(index).day}',
        subLabel: (index) {
          final day = start.addDays(index);
          return day.day == 1 || index == 0 ? month.format(day) : null;
        },
      );
    }

    return TrendChart(
      values: minutes,
      color: habit.color.shownIn(context),
      startDate: start,
      height: 132,
      format: label,
      axisFormat: axis,
    );
  }
}
