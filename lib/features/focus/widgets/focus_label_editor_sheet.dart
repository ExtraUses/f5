import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_palette.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/icons/habit_icons.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/focus/data/focus_label.dart';
import 'package:streak/features/focus/state/focus_labels_controller.dart';
import 'package:streak/features/focus/widgets/full_spectrum_color_picker.dart';

/// Modal sheet for creating or editing a [FocusLabel].
///
/// Surfaces three controls in a single vertically-scrolling sheet:
///   * The label name (text field, capped at [FocusLabel.maxNameLength]).
///   * The full-spectrum HSV color picker.
///   * An icon grid (Lucide icon registry).
///
/// Returns the saved [FocusLabel] via the future returned by
/// [showFocusLabelEditorSheet]. Returns `null` when the user cancels.
class FocusLabelEditorSheet extends StatefulWidget {
  const FocusLabelEditorSheet({super.key, this.existing});

  /// When non-null, the sheet is in edit mode and seeds every field from
  /// this label. When null, the sheet is in create mode and seeds the
  /// color from the active theme's primary.
  final FocusLabel? existing;

  @override
  State<FocusLabelEditorSheet> createState() => _FocusLabelEditorSheetState();
}

class _FocusLabelEditorSheetState extends State<FocusLabelEditorSheet> {
  late final TextEditingController _name;
  late Color _color;
  late String _icon;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.color ?? AppPalette.brand;
    _icon = widget.existing?.icon ?? HabitIcons.defaultIcon;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.focus_label_hint)),
      );
      return;
    }
    setState(() => _saving = true);
    final controller = context.read<FocusLabelsController>();
    FocusLabel? result;
    try {
      if (widget.existing == null) {
        result = await controller.create(
          name: name,
          color: _color,
          icon: _icon,
        );
      } else {
        final updated = widget.existing!.copyWith(
          name: name,
          color: _color,
          icon: _icon,
        );
        await controller.update(updated);
        result = updated;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(
                isEditing ? context.l10n.edit : context.l10n.focus_label_new,
                subtitle: context.l10n.focus_label_sub,
                trailing: _LabelPreview(color: _color, icon: _icon),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                autofocus: !isEditing,
                maxLength: FocusLabel.maxNameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.l10n.focus_label_hint,
                  labelText: context.l10n.focus_label,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 22),
              Text(
                context.l10n.colors_tab,
                style: sheetLabelStyle(
                  context,
                  size: 13,
                  color: context.tokens.muted,
                ),
              ),
              const SizedBox(height: 12),
              FullSpectrumColorPicker(
                selected: _color,
                onChanged: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 22),
              Text(
                context.l10n.focus_label_icon,
                style: sheetLabelStyle(
                  context,
                  size: 13,
                  color: context.tokens.muted,
                ),
              ),
              const SizedBox(height: 10),
              _IconGrid(
                selected: _icon,
                onSelected: (name) => setState(() => _icon = name),
                tint: _color,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelPreview extends StatelessWidget {
  const _LabelPreview({required this.color, required this.icon});

  final Color color;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Icon(
        FocusLabelIcons.resolve(icon),
        size: 22,
        color: color.computeLuminance() > 0.55
            ? const Color(0xFF1C1C1E)
            : color,
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.selected,
    required this.onSelected,
    required this.tint,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 6;
        const spacing = 8.0;
        final cell =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                .clamp(40.0, 52.0);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final name in FocusLabelIcons.names)
              Semantics(
                button: true,
                selected: selected == name,
                child: GestureDetector(
                  onTap: () => onSelected(name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: selected == name
                          ? tint.withValues(alpha: 0.18)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected == name ? tint : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: Icon(
                      FocusLabelIcons.resolve(name),
                      size: 20,
                      color: selected == name ? tint : scheme.onSurface,
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

/// Convenience entry point used by [FocusLabelPicker] and the future
/// Focus settings screen. Shows the editor in a bottom sheet and resolves
/// with the saved [FocusLabel] (or `null` if cancelled).
Future<FocusLabel?> showFocusLabelEditorSheet(
  BuildContext context, {
  FocusLabel? existing,
}) {
  return showModalBottomSheet<FocusLabel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FocusLabelEditorSheet(existing: existing),
  );
}
