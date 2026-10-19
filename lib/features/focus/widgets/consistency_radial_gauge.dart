import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/focus/data/focus_timeframe_stats.dart';
import 'package:streak/features/focus/state/focus_labels_controller.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

/// Circular donut chart for overall focus consistency.
///
/// Mirrors the visual language of the existing habit [ConsistencyGauge]:
///   * Thick stroke (12 px) with rounded caps.
///   * 270° sweep starting at 0.75π (top-left) and ending at 2.25π
///     (top-right), so the "gap" lives at the top of the ring.
///   * Track painted in surfaceContainerHighest, sweep painted with
///     a `color → color.withAlpha(0.45)` gradient.
///
/// The spec additionally asks for "clean gap spacing between colored
/// segments". We honor this by subdividing the sweep into one segment
/// per day in the window (up to a cap of 30 visible segments to avoid
/// visual clutter on long windows) and inserting a small angular gap
/// between adjacent segments. Each segment's color is the label that
/// contributed the most seconds on that day; if the day was inactive,
/// the segment is skipped (the track shows through).
class ConsistencyRadialGauge extends StatelessWidget {
  const ConsistencyRadialGauge({
    super.key,
    required this.stats,
    required this.accent,
    this.size = 170,
    this.colorOverride,
    this.maxSegments = 30,
  });

  final FocusTimeframeStats stats;
  final Color accent;

  /// Manual color override applied to every segment. When null, each
  /// segment paints with the dominant label's color for that day.
  final Color? colorOverride;

  final double size;

  /// Maximum number of segments rendered around the ring. When the
  /// window has more days than this, segments are aggregated into
  /// N-day buckets so the ring remains legible.
  final int maxSegments;

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<FocusLabelsController>();
    final segments = _buildSegments(labels);

    final percent = stats.consistencyPercent;
    final caption = '${stats.activeDays} / ${stats.totalDaysInWindow}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            tween: Tween(end: (percent / 100).clamp(0.0, 1.0)),
            builder: (context, t, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CustomPaint(
                    painter: _RadialGaugePainter(
                      progress: t,
                      accent: colorOverride ?? accent,
                      track: context.colors.surfaceContainerHighest,
                      segments: segments,
                    ),
                  ),
                ),
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(t * 100).round()}%',
                        style: statNumber(context, 30),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: size * 0.6,
                        child: Text(
                          context.l10n.focus_consistency_days(caption),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: statLabel(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build the list of segments that paint around the ring.
  ///
  /// Each entry is `(color, fractionOfFullRing)` where fractionOfFullRing
  /// is the angular share this day occupies (always 1/totalSegments).
  /// Inactive days produce a `null` color (track shows through).
  List<({Color? color, double fraction})> _buildSegments(
    FocusLabelsController labels,
  ) {
    final dayCount = stats.totalDaysInWindow;
    if (dayCount <= 0) return const [];

    // Aggregate so we never render more than [maxSegments] slices.
    final aggregateBy = dayCount > maxSegments
        ? (dayCount / maxSegments).ceil()
        : 1;

    final segmentCount = (dayCount / aggregateBy).ceil();
    final out = <({Color? color, double fraction})>[];
    for (var s = 0; s < segmentCount; s++) {
      // For each aggregated segment, find the dominant label across
      // the days it covers.
      final perLabel = <String, int>{};
      for (var d = s * aggregateBy;
          d < (s + 1) * aggregateBy && d < dayCount;
          d++) {
        if (d >= stats.series.length) break;
        if (stats.series[d] <= 0) continue;
        for (final entry in stats.perLabelPerDay.entries) {
          final seconds = entry.value[d];
          if (seconds == null || seconds <= 0) continue;
          perLabel[entry.key] = (perLabel[entry.key] ?? 0) + seconds;
        }
      }
      if (perLabel.isEmpty) {
        out.add((color: null, fraction: 1 / segmentCount));
        continue;
      }
      final top = (perLabel.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
      out.add((
        color: colorOverride ?? labels.colorOf(top, fallback: accent),
        fraction: 1 / segmentCount,
      ));
    }
    return out;
  }
}

class _RadialGaugePainter extends CustomPainter {
  const _RadialGaugePainter({
    required this.progress,
    required this.accent,
    required this.track,
    required this.segments,
  });

  final double progress;
  final Color accent;
  final Color track;
  final List<({Color? color, double fraction})> segments;

  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;
  static const _stroke = 12.0;
  static const _gapRadians = 0.012; // ~0.7° gap between segments

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(_stroke / 2, _stroke / 2) &
        Size(size.width - _stroke, size.height - _stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    // Full track ring.
    canvas.drawArc(rect, _start, _sweep, false, base);

    if (progress <= 0) return;
    final filledSweep = _sweep * progress;

    if (segments.isEmpty || segments.every((s) => s.color == null)) {
      // No per-day data — paint a uniform accent arc (matches the
      // existing habit ConsistencyGauge's behavior).
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: _start,
          endAngle: _start + _sweep,
          colors: [accent.withValues(alpha: 0.45), accent],
          transform: GradientRotation(_start),
        ).createShader(rect);
      canvas.drawArc(rect, _start, filledSweep, false, arc);
      return;
    }

    // Segmented sweep — paint each segment with its own color, leaving
    // a small angular gap between adjacent ones.
    var cursor = _start;
    var remaining = filledSweep;
    for (final segment in segments) {
      if (remaining <= _gapRadians * 2) break;
      final segSweep = (segment.fraction * _sweep) - _gapRadians;
      if (segSweep <= 0) continue;
      final paintedSweep = segSweep > remaining ? remaining : segSweep;
      if (segment.color != null) {
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = segment.color!;
        canvas.drawArc(rect, cursor, paintedSweep, false, arc);
      }
      cursor += segSweep + _gapRadians;
      remaining -= paintedSweep + _gapRadians;
    }
  }

  @override
  bool shouldRepaint(_RadialGaugePainter old) {
    if (old.progress != progress ||
        old.accent != accent ||
        old.track != track ||
        old.segments.length != segments.length) {
      return true;
    }
    // Deep-compare segment colors and fractions so label color edits
    // (which don't change the segment count) still trigger a repaint.
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].color != old.segments[i].color ||
          segments[i].fraction != old.segments[i].fraction) {
        return true;
      }
    }
    return false;
  }
}
