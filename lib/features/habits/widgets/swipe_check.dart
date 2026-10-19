import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SwipeCheck extends StatefulWidget {
  const SwipeCheck({
    super.key,
    required this.done,
    required this.tint,
    required this.corners,
    required this.onSwipe,
    required this.child,
  });

  final bool done;
  final Color tint;
  final BorderRadius corners;
  final VoidCallback? onSwipe;
  final Widget child;

  @override
  State<SwipeCheck> createState() => _SwipeCheckState();
}

class _SwipeCheckState extends State<SwipeCheck>
    with SingleTickerProviderStateMixin {
  static const _trigger = 0.28;

  late final AnimationController _offset;
  double _width = 1;
  bool _wasDone = false;

  double get _direction => _wasDone ? 1 : -1;

  bool get _armed => _offset.value.abs() >= _trigger;

  @override
  void initState() {
    super.initState();
    _offset = AnimationController(
      vsync: this,
      lowerBound: -1,
      upperBound: 1,
      value: 0,
    );
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _start(DragStartDetails details) {
    _wasDone = widget.done;
    _width = context.size?.width ?? 1;
  }

  void _drag(DragUpdateDetails details) {
    final next = _offset.value + details.primaryDelta! / _width;
    final along = (next * _direction).clamp(0.0, 0.6);
    _offset.value = along * _direction;
  }

  void _release(DragEndDetails details) {
    if (_armed) widget.onSwipe?.call();
    _offset.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onSwipe == null) return widget.child;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _drag,
          onHorizontalDragEnd: _release,
          onHorizontalDragCancel: () => _offset.animateTo(0),
          child: AnimatedBuilder(
            animation: _offset,
            child: widget.child,
            builder: (context, child) {
              final moving = _offset.value != 0;
              final armed = _armed;
              return Stack(
                children: [
                  Positioned.fill(
                    child: moving
                        ? _Reveal(
                            done: _wasDone,
                            armed: armed,
                            tint: widget.tint,
                            corners: widget.corners,
                          )
                        : const SizedBox.shrink(),
                  ),
                  FractionalTranslation(
                    translation: Offset(_offset.value, 0),
                    child: child,
                  ),
                ],
              );
            },
          ),
        );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.done,
    required this.armed,
    required this.tint,
    required this.corners,
  });

  final bool done;
  final bool armed;
  final Color tint;
  final BorderRadius corners;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corners,
        color: tint.withValues(alpha: armed ? 0.3 : 0.14),
      ),
      child: Align(
        alignment: done ? Alignment.centerLeft : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: armed ? 1.2 : 0.9,
            child: Icon(
              done ? LucideIcons.undo2 : LucideIcons.check,
              color: tint,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
