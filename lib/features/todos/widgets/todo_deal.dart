import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:streak/core/widgets/entrance.dart';
import 'package:streak/features/todos/widgets/folder_shape.dart';

const _outSpring = SpringDescription(mass: 0.6, stiffness: 300, damping: 24);
const _backSpring = SpringDescription(mass: 0.6, stiffness: 360, damping: 32);
const todoDealBack = Duration(milliseconds: 470);

class TodoDeal extends StatefulWidget {
  const TodoDeal({
    super.key,
    required this.home,
    required this.index,
    required this.child,
    this.dealing = false,
    this.closing = false,
    this.fresh = true,
    this.leaving = false,
  });

  final Rect? home;
  final int index;
  final bool dealing;
  final bool closing;
  final bool fresh;
  final bool leaving;
  final Widget child;

  static Animation<double>? progress(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Dealt>()?.progress;

  @override
  State<TodoDeal> createState() => _TodoDealState();
}

class _TodoDealState extends State<TodoDeal>
    with SingleTickerProviderStateMixin {
  late final bool _dealt = widget.home != null && widget.dealing;
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: _dealt ? 0 : 1,
  );
  Timer? _wait;
  late bool _hidden = _dealt;
  bool? _enter;

  Offset _shift = Offset.zero;
  Size _shrink = const Size(0.4, 0.4);
  double _turn = 0;

  @override
  void initState() {
    super.initState();
    if (!_dealt) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      setState(() => _hidden = false);
      _run(
        _outSpring,
        1,
        Duration(milliseconds: 55 * widget.index.clamp(0, 7)),
      );
    });
  }

  @override
  void didUpdateWidget(TodoDeal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.closing || oldWidget.closing || widget.home == null) return;
    _measure();
    _run(
      _backSpring,
      0,
      Duration(milliseconds: 22 * (6 - widget.index.clamp(0, 6))),
    );
  }

  void _run(SpringDescription spring, double target, Duration delay) {
    _wait?.cancel();
    _wait = Timer(delay, () {
      if (!mounted) return;
      _controller.animateWith(
        SpringSimulation(spring, _controller.value, target, 0),
      );
    });
  }

  void _measure() {
    final home = widget.home;
    final box = context.findRenderObject() as RenderBox?;
    if (home == null || box == null || !box.hasSize) return;
    final target = box.localToGlobal(Offset.zero) & box.size;
    final sheet = folderSheetRect(home, widget.index);
    _shift = sheet.center - target.center;
    _shrink = Size(
      sheet.width / target.width,
      sheet.height / math.max(target.height, 1),
    );
    _turn = folderSheetTurn(widget.index);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enter = _enter ??= !_dealt &&
        widget.fresh &&
        !(Scrollable.maybeOf(context)?.position.isScrollingNotifier.value ??
            false);
    final child = Entrance(
      index: widget.index,
      play: enter,
      leaving: widget.leaving,
      child: widget.child,
    );
    return _Dealt(
      progress: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        child: child,
        builder: (context, child) {
          final settle = _controller.value;
          final away = 1 - settle;
          final arc = math.sin(math.pi * settle.clamp(0.0, 1.0)) * 34;
          final moved = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(
                _shift.dx * away,
                _shift.dy * away - arc,
                0,
                1,
              )
              ..rotateZ(_turn * away)
              ..scaleByDouble(
                _shrink.width + (1 - _shrink.width) * settle,
                _shrink.height + (1 - _shrink.height) * settle,
                1,
                1,
              ),
            child: child,
          );
          return Opacity(opacity: _hidden ? 0 : 1, child: moved);
        },
      ),
    );
  }
}

class TodoShift extends StatefulWidget {
  const TodoShift({
    super.key,
    required this.id,
    required this.spots,
    required this.child,
  });

  final String id;
  final Map<String, Offset> spots;
  final Widget child;

  @override
  State<TodoShift> createState() => _TodoShiftState();
}

class _TodoShiftState extends State<TodoShift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  Offset _from = Offset.zero;

  Offset get _offset =>
      _from * (1 - Curves.easeOutCubic.transform(_slide.value));

  void _measure(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final scroll = Scrollable.maybeOf(context);
    final view = scroll?.context.findRenderObject();
    if (box == null || !box.attached || !box.hasSize || view == null) return;
    final at = box.localToGlobal(Offset.zero, ancestor: view) +
        Offset(0, scroll!.position.pixels);
    final before = widget.spots[widget.id];
    widget.spots[widget.id] = at;
    if (before == null || (before - at).distance < 1) return;
    _from = before + _offset - at;
    _slide.forward(from: 0);
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return AnimatedBuilder(
      animation: _slide,
      child: widget.child,
      builder: (context, child) =>
          Transform.translate(offset: _offset, child: child),
    );
  }
}

class _Dealt extends InheritedWidget {
  const _Dealt({required this.progress, required super.child});

  final Animation<double> progress;

  @override
  bool updateShouldNotify(_Dealt oldWidget) => progress != oldWidget.progress;
}

class TodoWrite extends StatelessWidget {
  const TodoWrite({super.key, required this.child});

  static final _frozen = SnapshotController(allowSnapshotting: true);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = TodoDeal.progress(context);
    if (progress == null) return child;
    final direction = Directionality.of(context);
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final written = ((progress.value - 0.35) / 0.65).clamp(0.0, 1.0);
        if (written >= 1) return child!;
        final edge = written * 1.4;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            stops: [math.max(0, edge - 0.35), math.min(1, edge)],
            colors: const [Colors.white, Colors.transparent],
          ).createShader(rect, textDirection: direction),
          child: SnapshotWidget(controller: _frozen, child: child),
        );
      },
    );
  }
}
