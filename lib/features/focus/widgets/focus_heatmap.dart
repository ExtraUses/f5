import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/focus/state/focus_controller.dart';

/// GitHub-style annual heatmap showing focus intensity per day.
///
/// Each cell represents one day. Color brightness scales with the total
/// focus time logged that day:
///   * 0 minutes → muted neutral gray/dark tone (empty/idle)
///   * 1-30 min → dim accent (light activity)
///   * 30-60 min → medium accent
///   * 1-2 hours → vivid accent
///   * 3+ hours → full-intensity accent
///
/// The heatmap spans the last 53 weeks (rolling), anchored to today.
class FocusHeatmap extends StatelessWidget {
  const FocusHeatmap({
    super.key,
    required this.accent,
    this.weeks = 53,
    this.cellSize = 12,
    this.gap = 3,
  });

  final Color accent;

  /// Number of weeks to display (default: 53 = ~1 year).
  final int weeks;

  /// Size of each day cell in logical pixels.
  final double cellSize;

  /// Gap between cells.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final scheme = context.colors;

    // Build per-day totals from all focus sessions.
    final dailyTotals = <String, int>{};
    for (final session in focus.sessions) {
      if (session.seconds < 30) continue;
      final key = session.countedOn.dayKey;
      dailyTotals[key] = (dailyTotals[key] ?? 0) + session.seconds;
    }

    // Find the max daily total for scaling.
    final maxSeconds = dailyTotals.values.fold<int>(0, (a, b) => b > a ? b : a);

    // Generate the grid: 7 rows (days) × N columns (weeks).
    final today = DateTime.now();
    final gridStart = today
        .subtract(Duration(days: weeks * 7))
        .atMidnight;

    final columns = <List<_HeatCell>>[];
    var cursor = gridStart;
    while (cursor.isBefore(today) || cursor.atMidnight == today.atMidnight) {
      final week = <_HeatCell>[];
      for (var d = 0; d < 7; d++) {
        final day = cursor.addDays(d);
        if (day.isAfter(today)) {
          week.add(_HeatCell(date: day, seconds: 0, isFuture: true));
        } else {
          final seconds = dailyTotals[day.dayKey] ?? 0;
          week.add(_HeatCell(date: day, seconds: seconds, isFuture: false));
        }
      }
      columns.add(week);
      cursor = cursor.addDays(7);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heatmap grid.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: CustomPaint(
            size: Size(
              columns.length * (cellSize + gap),
              7 * (cellSize + gap),
            ),
            painter: _HeatmapPainter(
              columns: columns,
              accent: accent,
              track: scheme.surfaceContainerHighest,
              maxSeconds: maxSeconds,
              cellSize: cellSize,
              gap: gap,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend: less → more.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              context.l10n.focus_heatmap,
              style: sheetLabelStyle(
                context,
                size: 11,
                color: context.tokens.muted,
              ),
            ),
            const Spacer(),
            for (var i = 0; i <= 4; i++) ...[
              const SizedBox(width: 3),
              Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  color: _colorForLevel(i, accent, scheme.surfaceContainerHighest, maxSeconds),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              'Less',
              style: TextStyle(
                fontSize: 10,
                color: context.tokens.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _colorForLevel(
    int level,
    Color accent,
    Color track,
    int maxSeconds,
  ) {
    if (level == 0) return track.withValues(alpha: 0.4);
    final ratio = (level / 4.0).clamp(0.2, 1.0);
    return accent.withValues(alpha: ratio);
  }
}

class _HeatCell {
  const _HeatCell({
    required this.date,
    required this.seconds,
    this.isFuture = false,
  });

  final DateTime date;
  final int seconds;
  final bool isFuture;
}

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter({
    required this.columns,
    required this.accent,
    required this.track,
    required this.maxSeconds,
    required this.cellSize,
    required this.gap,
  });

  final List<List<_HeatCell>> columns;
  final Color accent;
  final Color track;
  final int maxSeconds;
  final double cellSize;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = cellSize / 2.5;
    for (var col = 0; col < columns.length; col++) {
      for (var row = 0; row < columns[col].length; row++) {
        final cell = columns[col][row];
        final x = col * (cellSize + gap);
        final y = row * (cellSize + gap);
        final rect = Rect.fromLTWH(x, y, cellSize, cellSize);

        final paint = Paint()
          ..color = _colorForCell(cell)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          paint,
        );
      }
    }
  }

  Color _colorForCell(_HeatCell cell) {
    if (cell.isFuture) return track.withValues(alpha: 0.2);
    if (cell.seconds <= 0) return track.withValues(alpha: 0.4);

    // Scale brightness: 0 min = track, 30 min = 0.3, 1h = 0.55, 2h = 0.8, 3h+ = 1.0
    final minutes = cell.seconds / 60.0;
    final ratio = (minutes / 180.0).clamp(0.15, 1.0);
    return accent.withValues(alpha: ratio);
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.columns.length != columns.length ||
      old.accent != accent ||
      old.maxSeconds != maxSeconds;
}
