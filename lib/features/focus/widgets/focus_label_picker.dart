import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/app_confirm_dialog.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/focus/data/focus_label.dart';
import 'package:streak/features/focus/state/focus_labels_controller.dart';
import 'package:streak/features/focus/widgets/focus_label_editor_sheet.dart';

/// Standalone Focus Label picker.
///
/// Replaces the legacy habit-bound label list with a decoupled chip row
/// backed by [FocusLabelsController]. Each chip paints itself with the
/// label's [FocusLabel.color] so the user sees the exact hue they assigned
/// — this is the contract required by the analytics widgets in Phase 3,
/// where each segment of the stacked bar chart will use the same color.
///
/// The constructor signature is preserved from the legacy widget so the
/// existing call site in [focus_habit_card.dart] keeps compiling without
/// changes; [habitId] is accepted but ignored (labels are no longer
/// subordinated to habits), and [selected] is reinterpreted as a
/// [FocusLabel.id] string. Callers that still pass a free-form label text
/// will be migrated on the first call to [FocusLabelsController._migrateLegacy].
class FocusLabelPicker extends StatelessWidget {
  const FocusLabelPicker({
    super.key,
    @Deprecated('Labels are decoupled from habits as of v2.4.0. '
        'This parameter is accepted for source-compatibility only.')
    required this.habitId,
    required this.selected,
    required this.onChanged,
  });

  static const maxLength = FocusLabel.maxNameLength;

  // ignore: unused_element_parameter
  final String habitId;
  final String selected;
  final ValueChanged<String> onChanged;

  Future<void> _createLabel(BuildContext context) async {
    final created = await showFocusLabelEditorSheet(context);
    if (created != null && context.mounted) onChanged(created.id);
  }

  Future<void> _editLabel(BuildContext context, FocusLabel label) async {
    await showFocusLabelEditorSheet(context, existing: label);
  }

  Future<void> _archiveLabel(
    BuildContext context,
    FocusLabelsController controller,
    FocusLabel label,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.focus_label_remove,
      message: context.l10n.focus_label_remove_body(label.name),
      confirmLabel: context.l10n.focus_label_remove_confirm,
    );
    if (confirmed != true || !context.mounted) return;
    await controller.archive(label.id);
    if (selected == label.id) onChanged('');
  }

  Future<void> _deleteLabel(
    BuildContext context,
    FocusLabelsController controller,
    FocusLabel label,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.focus_label_remove,
      message: context.l10n.focus_label_remove_body(label.name),
      confirmLabel: context.l10n.focus_label_remove_confirm,
    );
    if (confirmed != true || !context.mounted) return;
    await controller.remove(label.id);
    if (selected == label.id) onChanged('');
  }

  void _showLabelMenu(
    BuildContext context,
    FocusLabelsController controller,
    FocusLabel label,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(LucideIcons.pencil, color: context.colors.primary),
                title: Text(context.l10n.edit),
                onTap: () {
                  Navigator.of(context).pop();
                  _editLabel(context, label);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.archive, color: context.tokens.warning),
                title: Text(context.l10n.focus_label_remove),
                onTap: () {
                  Navigator.of(context).pop();
                  _archiveLabel(context, controller, label);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.trash2, color: context.tokens.danger),
                title: Text(context.l10n.delete),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteLabel(context, controller, label);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FocusLabelsController>();
    final labels = controller.visible;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FocusLabelChip(
          label: context.l10n.focus_label_none,
          color: context.tokens.muted,
          selected: selected.isEmpty,
          onTap: () => onChanged(''),
        ),
        for (final label in labels)
          FocusLabelChip(
            label: label.name,
            color: label.color,
            icon: FocusLabelIcons.resolve(label.icon),
            selected: selected == label.id,
            onTap: () => onChanged(label.id),
            onLongPress: () => _showLabelMenu(context, controller, label),
          ),
        FocusLabelChip(
          label: context.l10n.focus_label_new,
          icon: LucideIcons.plus,
          color: context.colors.primary,
          selected: false,
          onTap: () => _createLabel(context),
        ),
      ],
    );
  }
}

/// Material-You compliant chip that paints itself with the label's color.
///
/// When selected, the chip's background fills with a translucent version
/// of [color] and the outline matches [color] — so the user sees the
/// exact hue that will be used as the segment color in the analytics
/// stacked bar chart.
class FocusLabelChip extends StatelessWidget {
  const FocusLabelChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onLongPress,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final chip = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? (color.computeLuminance() > 0.55
                          ? const Color(0xFF1C1C1E)
                          : color)
                      : color,
                ),
                const SizedBox(width: 6),
              ] else if (selected) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: sheetLabelStyle(
                  context,
                  size: 13,
                  color: selected
                      ? (color.computeLuminance() > 0.55
                          ? const Color(0xFF1C1C1E)
                          : color)
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onLongPress == null) return chip;
    return GestureDetector(onLongPress: onLongPress, child: chip);
  }
}
