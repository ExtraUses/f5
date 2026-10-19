import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/utils/responsive.dart';
import 'package:streak/core/widgets/scrolling_text.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/habits/data/category.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_tag.dart';
import 'package:streak/features/todos/widgets/todo_labels.dart';

class TodoSticker extends StatelessWidget {
  const TodoSticker({
    super.key,
    required this.priority,
    this.turn = 0,
    this.scale = 1,
  });

  final TodoPriority priority;
  final double turn;
  final double scale;

  static double turnFor(String id) =>
      (id.codeUnits.fold(0, (sum, unit) => sum + unit) % 9 - 4) * 0.018;

  @override
  Widget build(BuildContext context) {
    if (priority == TodoPriority.none) return const SizedBox.shrink();
    final (icon, color) = switch (priority) {
      TodoPriority.low => (LucideIcons.coffee, const Color(0xFF4F9DDE)),
      TodoPriority.medium => (LucideIcons.hourglass, const Color(0xFFF0A13A)),
      _ => (LucideIcons.flame, const Color(0xFFEF5B4C)),
    };
    return _Sticker(
      icon: icon,
      label: todoPriorityLabels(context)[priority.index],
      color: color,
      turn: turn,
      scale: scale,
    );
  }
}

class ProjectSticker extends StatelessWidget {
  const ProjectSticker({
    super.key,
    required this.project,
    this.turn = 0,
    this.scale = 1,
  });

  final TodoTag project;
  final double turn;
  final double scale;

  @override
  Widget build(BuildContext context) => _Sticker(
        icon: CategoryIcons.resolve(project.icon),
        label: project.name,
        color: project.color,
        turn: turn,
        scale: scale,
      );
}

class _Sticker extends StatelessWidget {
  const _Sticker({
    required this.icon,
    required this.label,
    required this.color,
    required this.turn,
    required this.scale,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double turn;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 10.5 * scale;

    return Transform.rotate(
      angle: turn,
      child: Container(
        padding: EdgeInsets.fromLTRB(6 * scale, 3 * scale, 8 * scale, 3 * scale),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7 * scale),
          border: Border.all(color: Colors.white, width: 2 * scale),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.22)!, color],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 3 * scale,
              offset: Offset(0, 1.5 * scale),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: size, color: Colors.white),
            SizedBox(width: 4 * scale),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 120 * scale),
              child: ScrollingLine(
              rounds: 1,
              replayOnScrollUp: true,
              child: Text(
              label.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: size - 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                height: 1.1,
                color: Colors.white,
              ),
            ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodoPin extends StatelessWidget {
  const TodoPin({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFEF5B4C);
    return Transform.rotate(
      angle: -0.35,
      child: Container(
        width: 24 * scale,
        height: 24 * scale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2 * scale),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.25)!, color],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 3 * scale,
              offset: Offset(0, 1.5 * scale),
            ),
          ],
        ),
        child: Icon(LucideIcons.pin, size: 12 * scale, color: Colors.white),
      ),
    );
  }
}

Future<void> showTodoPriorityPicker(
  BuildContext context, {
  required TodoPriority selected,
  required ValueChanged<TodoPriority> onPicked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: phoneWidth),
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.todo_priority, style: sheetTitleStyle(sheet)),
            const SizedBox(height: 16),
            for (final row in const [
              [TodoPriority.high, TodoPriority.medium],
              [TodoPriority.low, TodoPriority.none],
            ]) ...[
              Row(
                children: [
                  for (final (index, priority) in row.indexed) ...[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _PriorityTile(
                        priority: priority,
                        selected: priority == selected,
                        onTap: () {
                          Navigator.of(sheet).pop();
                          onPicked(priority);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PriorityTile extends StatelessWidget {
  const _PriorityTile({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TodoPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: todoPriorityLabels(context)[priority.index],
      excludeSemantics: true,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: 84,
            child: Center(
              child: priority == TodoPriority.none
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.flagOff, size: 16, color: muted),
                        const SizedBox(width: 7),
                        Text(
                          todoPriorityLabels(context)[0],
                          style: sheetActionStyle(context, size: 14, color: muted),
                        ),
                      ],
                    )
                  : TodoSticker(priority: priority, turn: -0.05, scale: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}
