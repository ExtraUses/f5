import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/routing/back_handlers.dart';
import 'package:streak/core/widgets/sheet_type.dart';

class HoldMenuAction {
  const HoldMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool danger;
}

typedef HoldPreviewBuilder = Widget Function(BuildContext context, bool lifted);

class HoldMenu extends StatefulWidget {
  const HoldMenu({
    super.key,
    required this.actions,
    required this.preview,
    required this.child,
  });

  final List<HoldMenuAction> actions;
  final HoldPreviewBuilder preview;
  final Widget child;

  static HoldMenuState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<HoldMenuState>();

  @override
  State<HoldMenu> createState() => HoldMenuState();
}

class HoldMenuState extends State<HoldMenu>
    with SingleTickerProviderStateMixin {
  static const _button = 56.0;
  static const _reach = 46.0;
  static const _edge = 14.0;

  late final AnimationController _motion;
  late final Animation<double> _fade = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );
  late final Animation<double> _lift = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  late final List<Animation<double>> _steps = [
    for (var i = 0; i < widget.actions.length; i++)
      CurvedAnimation(
        parent: _motion,
        curve: Interval(
          0.08 + 0.1 * i,
          math.min(1, 0.62 + 0.1 * i),
          curve: Curves.easeOutBack,
        ),
        reverseCurve: Curves.easeInCubic,
      ),
  ];

  final _hovered = ValueNotifier<int?>(null);
  OverlayEntry? _entry;
  Rect _anchor = Rect.zero;
  Offset _origin = Offset.zero;
  List<Offset> _spots = const [];
  Offset _labelAt = Offset.zero;
  double _tilt = 0;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    if (_entry != null) {
      BackHandlers.remove(_backOut);
      _entry!.remove();
    }
    _hovered.dispose();
    _motion.dispose();
    super.dispose();
  }

  bool _backOut() {
    if (_entry == null) return false;
    _close(null);
    return true;
  }

  void _measure(Offset? finger) {
    final box = context.findRenderObject()! as RenderBox;
    _anchor = box.localToGlobal(Offset.zero) & box.size;
    final media = MediaQuery.of(context);
    final screen = Offset.zero & media.size;
    _origin = finger ?? _anchor.center;
    _tilt = _origin.dx < screen.width / 2 ? -0.03 : 0.03;

    final count = widget.actions.length;
    final span = _button + 12;
    final room = _button + _edge * 2;
    final spaceLeft = _anchor.left;
    final spaceRight = screen.width - _anchor.right;
    final mid = (count - 1) / 2;
    List<Offset> spots;
    if (math.max(spaceLeft, spaceRight) >= room) {
      final right = spaceRight >= spaceLeft;
      final x = right
          ? _anchor.right + _edge + _button / 2
          : _anchor.left - _edge - _button / 2;
      spots = [
        for (var i = 0; i < count; i++)
          Offset(
            x + (right ? -1 : 1) * (i - mid) * (i - mid) * 7,
            _origin.dy + (i - mid) * span,
          ),
      ];
    } else {
      final above = _anchor.top - media.padding.top > room + 40;
      final y = above
          ? _anchor.top - _edge - _button / 2
          : _anchor.bottom + _edge + _button / 2;
      spots = [
        for (var i = 0; i < count; i++)
          Offset(
            _origin.dx + (i - mid) * (span + 6),
            y + (above ? 1 : -1) * (i - mid) * (i - mid) * 7,
          ),
      ];
    }

    final half = _button / 2 + _edge;
    final left = half;
    final right = screen.width - half;
    final top = media.padding.top + half + 30;
    final bottom = screen.height - media.padding.bottom - half;
    var dx = 0.0;
    var dy = 0.0;
    for (final spot in spots) {
      if (spot.dx < left) dx = math.max(dx, left - spot.dx);
      if (spot.dx > right) dx = math.min(dx, right - spot.dx);
      if (spot.dy < top) dy = math.max(dy, top - spot.dy);
      if (spot.dy > bottom) dy = math.min(dy, bottom - spot.dy);
    }
    spots = [for (final spot in spots) spot + Offset(dx, dy)];
    _spots = spots;
    final overhead = _anchor.top - media.padding.top > 56;
    _labelAt = Offset(
      _anchor.center.dx,
      overhead ? _anchor.top - 30 : _anchor.bottom + 30,
    );
  }

  void open([Offset? finger]) {
    if (_entry != null) return;
    _measure(finger);
    _hovered.value = null;
    final entry = OverlayEntry(builder: _build);
    _entry = entry;
    Overlay.of(context).insert(entry);
    BackHandlers.add(_backOut);
    _motion.forward(from: 0);
    setState(() {});
  }

  Future<void> _close(int? picked) async {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    BackHandlers.remove(_backOut);
    if (picked != null) _hovered.value = picked;
    await _motion.reverse();
    entry.remove();
    if (!mounted) return;
    setState(() {});
    if (picked != null) widget.actions[picked].onSelected();
  }

  void _slide(Offset finger) {
    int? nearest;
    var best = _reach;
    for (final (index, spot) in _spots.indexed) {
      final distance = (spot - finger).distance;
      if (distance < best) {
        best = distance;
        nearest = index;
      }
    }
    _hovered.value = nearest;
  }

  Widget _build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(null),
              child: FadeTransition(
                opacity: _fade,
                child: const ColoredBox(color: Color(0x99000000)),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: _anchor,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _lift,
                builder: (context, child) => Transform.rotate(
                  angle: _tilt * _lift.value,
                  child: Transform.scale(
                    scale: 1 + 0.05 * _lift.value,
                    child: child,
                  ),
                ),
                child: widget.preview(context, true),
              ),
            ),
          ),
          Positioned(
            left: _origin.dx - 26,
            top: _origin.dy - 26,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _fade,
                builder: (context, _) => Opacity(
                  opacity: _fade.value * 0.9,
                  child: Transform.scale(
                    scale: 0.4 + 0.6 * _fade.value,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (final (index, action) in widget.actions.indexed)
            _HaloButton(
              action: action,
              index: index,
              origin: _origin,
              spot: _spots[index],
              motion: _steps[index],
              hovered: _hovered,
              onTap: () => _close(index),
            ),
          ValueListenableBuilder<int?>(
            valueListenable: _hovered,
            builder: (context, hovered, _) => _HaloLabel(
              action: hovered == null ? null : widget.actions[hovered],
              at: _labelAt,
              motion: _fade,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) => open(details.globalPosition),
      onLongPressMoveUpdate: (details) => _slide(details.globalPosition),
      onLongPressEnd: (_) {
        if (_hovered.value != null) _close(_hovered.value);
      },
      onSecondaryTapUp: (details) => open(details.globalPosition),
      child: Opacity(opacity: _entry == null ? 1 : 0, child: widget.child),
    );
  }
}

class _HaloButton extends StatelessWidget {
  const _HaloButton({
    required this.action,
    required this.index,
    required this.origin,
    required this.spot,
    required this.motion,
    required this.hovered,
    required this.onTap,
  });

  static const _size = HoldMenuState._button;

  final HoldMenuAction action;
  final int index;
  final Offset origin;
  final Offset spot;
  final Animation<double> motion;
  final ValueListenable<int?> hovered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tone = action.danger ? context.tokens.danger : scheme.primary;

    return AnimatedBuilder(
      animation: motion,
      builder: (context, child) {
        final t = motion.value;
        final at = Offset.lerp(origin, spot, t)!;
        return Positioned(
          left: at.dx - _size / 2,
          top: at.dy - _size / 2,
          width: _size,
          height: _size,
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
          ),
        );
      },
      child: Semantics(
        button: true,
        label: action.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ValueListenableBuilder<int?>(
            valueListenable: hovered,
            builder: (context, current, _) {
              final on = current == index;
              return AnimatedScale(
                scale: on ? 1.18 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? tone : scheme.surface,
                    border: Border.all(
                      color: on
                          ? Colors.white.withValues(alpha: 0.7)
                          : tone.withValues(alpha: action.danger ? 0.35 : 0.12),
                      width: on ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (on ? tone : Colors.black)
                            .withValues(alpha: on ? 0.45 : 0.28),
                        blurRadius: on ? 22 : 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    action.icon,
                    size: 22,
                    color: on
                        ? Colors.white
                        : action.danger
                            ? tone
                            : scheme.onSurface,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HaloLabel extends StatelessWidget {
  const _HaloLabel({
    required this.action,
    required this.at,
    required this.motion,
  });

  final HoldMenuAction? action;
  final Offset at;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final action = this.action;
    if (action == null) return const SizedBox.shrink();
    final tone = action.danger ? context.tokens.danger : context.colors.onSurface;
    return Positioned(
      left: 12,
      right: 12,
      top: at.dy - 18,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment(((at.dx / width) * 2 - 1).clamp(-1.0, 1.0), 0),
          child: FadeTransition(
            opacity: motion,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(action.label),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 6 * (1 - t)),
                  child: child,
                ),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  action.label,
                  style: sheetOptionStyle(
                    context,
                    size: 14,
                    selected: true,
                    color: tone,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

