import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/minimal/minimal_kit.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/habits/data/category.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/todos/data/todo_tag.dart';
import 'package:streak/features/todos/widgets/folder_shape.dart';

const _land = SpringDescription(mass: 0.7, stiffness: 260, damping: 22);
const _back = SpringDescription(mass: 0.6, stiffness: 360, damping: 32);

class TodoEmptyFolder extends StatefulWidget {
  const TodoEmptyFolder({
    super.key,
    required this.project,
    required this.home,
    required this.closing,
    required this.onAdd,
  });

  final TodoTag? project;
  final Rect? home;
  final bool closing;
  final VoidCallback onAdd;

  @override
  State<TodoEmptyFolder> createState() => _TodoEmptyFolderState();
}

class _TodoEmptyFolderState extends State<TodoEmptyFolder>
    with TickerProviderStateMixin {
  late final AnimationController _fly = AnimationController.unbounded(
    vsync: this,
    value: widget.home == null ? 1 : 0,
  );
  late final AnimationController _shrug = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );
  final _art = GlobalKey();
  Timer? _wait;
  Offset _shift = Offset.zero;
  late bool _hidden = widget.home != null;

  @override
  void initState() {
    super.initState();
    if (widget.home == null) {
      _shrug.forward();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      setState(() => _hidden = false);
      _fly.animateWith(SpringSimulation(_land, 0, 1, 0));
      _wait = Timer(const Duration(milliseconds: 380), () {
        if (mounted) _shrug.forward();
      });
    });
  }

  @override
  void didUpdateWidget(TodoEmptyFolder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.closing || oldWidget.closing || widget.home == null) return;
    _measure();
    _fly.animateWith(SpringSimulation(_back, _fly.value, 0, 0));
  }

  void _measure() {
    final home = widget.home;
    final box = _art.currentContext?.findRenderObject() as RenderBox?;
    if (home == null || box == null || !box.hasSize) return;
    final spot = box.localToGlobal(Offset.zero) & box.size;
    _shift = home.center - spot.center;
  }

  @override
  void dispose() {
    _wait?.cancel();
    _fly.dispose();
    _shrug.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final minimal = context.watch<SettingsController>().isMinimalStyle;
    final folder = SizedBox(
      key: _art,
      width: widget.home?.width ?? 150,
      height: widget.home?.height ?? 117,
      child: FolderShape(
        color: project?.color ?? context.tokens.muted,
        icon: project == null
            ? LucideIcons.inbox
            : CategoryIcons.resolve(project.icon),
        papers: 0,
        seed: project == null
            ? 0
            : project.id.codeUnits.fold(0, (sum, unit) => sum + unit),
      ),
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 20, 40, 120),
        child: AnimatedBuilder(
          animation: Listenable.merge([_fly, _shrug]),
          builder: (context, _) {
            final settle = _fly.value;
            final away = 1 - settle;
            final shrug = _shrug.value;
            final words = ((settle - 0.55) / 0.45).clamp(0.0, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _hidden ? 0 : 1,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(
                        _shift.dx * away,
                        _shift.dy * away,
                        0,
                        1,
                      )
                      ..rotateZ(
                        math.sin(shrug * math.pi * 4) * 0.06 * (1 - shrug),
                      ),
                    child: folder,
                  ),
                ),
                const SizedBox(height: 30),
                Opacity(
                  opacity: words,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - words)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.todo_project_empty,
                          textAlign: TextAlign.center,
                          style: sheetTitleStyle(context, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.todo_empty_body,
                          textAlign: TextAlign.center,
                          style: sheetBodyStyle(context, size: 14),
                        ),
                        const SizedBox(height: 22),
                        minimal
                            ? MinimalButton(
                                icon: LucideIcons.plus,
                                label: context.l10n.todo_new,
                                height: 48,
                                onPressed: widget.onAdd,
                              )
                            : FilledButton.icon(
                                onPressed: widget.onAdd,
                                icon: const Icon(LucideIcons.plus, size: 18),
                                label: Text(context.l10n.todo_new),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
