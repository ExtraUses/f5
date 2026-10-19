import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:streak/app/app_background.dart';

class MorphRoute<T> extends PageRoute<T> {
  MorphRoute({
    required this.page,
    required this.origin,
    required this.icon,
    required this.ink,
    required this.edge,
  }) : super(fullscreenDialog: true);

  final Widget page;
  final Rect origin;
  final IconData icon;
  final Color ink;
  final Color edge;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 520);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      AppBackground(child: page);

  static double _span(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    final content = RepaintBoundary(child: child);
    return AnimatedBuilder(
      animation: animation,
      child: content,
      builder: (context, page) {
        final t = animation.value;
        final grow = Curves.easeInOutCubic.transform(_span(t, 0, 0.85));
        final squeeze = 1 - 0.1 * math.sin(math.pi * _span(t, 0, 0.3));
        final from = Rect.fromCenter(
          center: origin.center,
          width: origin.width * squeeze,
          height: origin.height * squeeze,
        );
        final rect = Rect.lerp(from, screen, grow)!;
        final radius = lerpDouble(origin.shortestSide / 2, 0, grow)!;
        final glyph = 1 - _span(t, 0, 0.3);
        final shown = Curves.easeOut.transform(_span(t, 0.4, 1));
        return Stack(
          children: [
            ClipRRect(
              clipper: _RectClip(rect, radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const AppBackground(child: SizedBox.expand()),
                  Opacity(opacity: shown, child: page),
                ],
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: edge.withValues(alpha: 1 - grow),
                    ),
                  ),
                ),
              ),
            ),
            if (glyph > 0)
              Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: rect.center,
                  width: origin.width,
                  height: origin.height,
                ),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: glyph,
                    child: Transform.rotate(
                      angle: math.pi / 2 * (1 - glyph),
                      child: Icon(icon, size: 19, color: ink),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RectClip extends CustomClipper<RRect> {
  const _RectClip(this.rect, this.radius);

  final Rect rect;
  final double radius;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_RectClip old) =>
      old.rect != rect || old.radius != radius;
}
