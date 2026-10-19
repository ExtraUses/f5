import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/settings/state/settings_controller.dart';

class TodoCheck extends StatefulWidget {
  const TodoCheck({
    super.key,
    required this.title,
    required this.done,
    required this.ring,
    required this.onToggle,
    this.fill,
    this.tick,
  });

  final String title;
  final bool done;
  final Color ring;
  final VoidCallback onToggle;
  final Color? fill;
  final Color? tick;

  @override
  State<TodoCheck> createState() => _TodoCheckState();
}

class _TodoCheckState extends State<TodoCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: widget.done ? 1 : 0,
  );
  bool _pressed = false;

  @override
  void didUpdateWidget(TodoCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done == oldWidget.done) return;
    widget.done ? _progress.forward() : _progress.reverse();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final circle = context.watch<SettingsController>().isCircleCheck;

    return Semantics(
      container: true,
      button: true,
      checked: widget.done,
      label: widget.done
          ? context.l10n.a11y_mark_not_done(widget.title)
          : context.l10n.a11y_mark_done(widget.title),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onToggle,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox.square(
            dimension: 26,
            child: CustomPaint(
              painter: _CheckPainter(
                progress: _progress,
                ring: widget.ring,
                fill: widget.fill ?? scheme.primary,
                mark: widget.tick ?? scheme.onPrimary,
                circle: circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.progress,
    required this.ring,
    required this.fill,
    required this.mark,
    required this.circle,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color ring;
  final Color fill;
  final Color mark;
  final bool circle;

  Path _shape(Rect rect) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(circle ? rect.width / 2 : rect.width * 0.3),
      ),
    );

  Path _dashed(Path shape) {
    final dashed = Path();
    for (final metric in shape.computeMetrics()) {
      final count = math.max(1, (metric.length / 5.6).round());
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        dashed.addPath(
          metric.extractPath(i * step, i * step + step * 0.42),
          Offset.zero,
        );
      }
    }
    return dashed;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final shape = _shape((Offset.zero & size).deflate(1.2));

    if (t < 1) {
      canvas.drawPath(
        _dashed(shape),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round
          ..color = ring.withValues(alpha: 1 - t),
      );
    }
    if (t <= 0) return;

    canvas.drawPath(
      shape,
      Paint()..color = fill.withValues(alpha: math.min(1, t * 3)),
    );
    final tick = Path()
      ..moveTo(size.width * 0.29, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.72, size.height * 0.36);
    final metric = tick.computeMetrics().first;
    final drawn = Curves.easeOut.transform(((t - 0.25) / 0.75).clamp(0.0, 1.0));
    canvas.drawPath(
      metric.extractPath(0, metric.length * drawn),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = mark,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.ring != ring ||
      old.fill != fill ||
      old.mark != mark ||
      old.circle != circle;
}
