import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/sheet_type.dart';

class TodoSelectBar extends StatelessWidget {
  const TodoSelectBar({
    super.key,
    required this.count,
    required this.pinned,
    required this.onClose,
    required this.onPin,
    required this.onEdit,
    required this.onDone,
    required this.onDelete,
  });

  final int count;
  final bool pinned;
  final VoidCallback onClose;
  final VoidCallback onPin;
  final VoidCallback onEdit;
  final VoidCallback onDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final danger = context.tokens.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Icon(
            icon: LucideIcons.x,
            label: MaterialLocalizations.of(context).closeButtonLabel,
            onTap: onClose,
          ),
          Flexible(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                context.l10n.todo_selected(count),
                key: ValueKey(count),
                style: sheetActionStyle(context, size: 14.5),
              ),
            ),
            ),
            ),
          ),
          _Icon(
            icon: pinned ? LucideIcons.pinOff : LucideIcons.pin,
            label: pinned ? context.l10n.todo_unpin : context.l10n.todo_pin,
            onTap: onPin,
          ),
          _Icon(
            icon: LucideIcons.pencil,
            label: context.l10n.edit,
            onTap: onEdit,
          ),
          _Icon(
            icon: LucideIcons.checkCheck,
            label: context.l10n.todo_mark_done,
            onTap: onDone,
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: context.l10n.delete,
            excludeSemantics: true,
            child: Material(
              color: danger,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20, color: context.colors.onSurface),
    );
  }
}

class TodoSelectable extends StatelessWidget {
  const TodoSelectable({
    super.key,
    required this.selecting,
    required this.selected,
    required this.radius,
    required this.child,
  });

  final bool selecting;
  final bool selected;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return AnimatedScale(
      scale: selected ? 0.95 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 4),
                  border: Border.all(
                    color: selected ? accent : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: -8,
            start: -8,
            child: IgnorePointer(
              child: AnimatedScale(
                scale: selecting ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: selecting ? Curves.easeOutBack : Curves.easeInCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accent : context.colors.surface,
                    border: Border.all(
                      color: selected
                          ? Colors.white
                          : context.colors.onSurface.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: selected
                        ? Icon(
                            LucideIcons.check,
                            key: const ValueKey(true),
                            size: 15,
                            color: context.colors.onPrimary,
                          )
                        : const SizedBox.shrink(key: ValueKey(false)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
