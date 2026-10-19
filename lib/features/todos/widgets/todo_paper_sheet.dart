import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/utils/cover_storage.dart';
import 'package:streak/core/widgets/cover_image.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/todos/widgets/todo_paper.dart';

Future<void> showTodoPaperPicker(
  BuildContext context, {
  required int selected,
  required String cover,
  required ValueChanged<int> onPicked,
  required ValueChanged<String> onCover,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetTitle(sheet.l10n.todo_paper),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Swatch(
                      color: sheetColor(sheet, -1),
                      picked: selected < 0,
                      auto: true,
                      onTap: () {
                        Navigator.of(sheet).pop();
                        onPicked(-1);
                      },
                    ),
                    for (var index = 0; index < todoPapers.length; index++)
                      _Swatch(
                        color: sheetColor(sheet, index),
                        picked: selected == index,
                        onTap: () {
                          Navigator.of(sheet).pop();
                          onPicked(index);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SheetTitle(sheet.l10n.todo_background),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Backdrop(
                    picked: cover.isEmpty,
                    label: sheet.l10n.todo_paper,
                    onTap: () {
                      Navigator.of(sheet).pop();
                      onCover('');
                    },
                    child: Icon(
                      LucideIcons.imageOff,
                      size: 20,
                      color: sheet.tokens.muted,
                    ),
                  ),
                  if (CoverImage.exists(cover))
                    _Backdrop(
                      picked: true,
                      label: sheet.l10n.todo_background,
                      onTap: () => Navigator.of(sheet).pop(),
                      child: SizedBox.expand(child: CoverImage(path: cover)),
                    ),
                  _Backdrop(
                    picked: false,
                    label: sheet.l10n.todo_background_pick,
                    onTap: () async {
                      Navigator.of(sheet).pop();
                      final path = await CoverStorage.store(folder: 'todos');
                      if (path != null) onCover(path);
                    },
                    child: Icon(
                      LucideIcons.imagePlus,
                      size: 20,
                      color: sheet.colors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.picked,
    required this.onTap,
    this.auto = false,
  });

  final Color color;
  final bool picked;
  final VoidCallback onTap;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Semantics(
        button: true,
        selected: picked,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: picked
                    ? context.colors.onSurface
                    : context.colors.onSurface.withValues(alpha: 0.12),
                width: picked ? 2.5 : 1,
              ),
            ),
            child: Icon(
              picked
                  ? LucideIcons.check
                  : (auto ? LucideIcons.dropletOff : null),
              size: 18,
              color: inkOf(context).withValues(alpha: picked ? 0.75 : 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.picked,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final bool picked;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Semantics(
        button: true,
        selected: picked,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: picked
                    ? context.colors.onSurface
                    : context.colors.onSurface.withValues(alpha: 0.12),
                width: picked ? 2.5 : 1,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
