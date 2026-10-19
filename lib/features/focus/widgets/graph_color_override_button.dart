import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/focus/widgets/full_spectrum_color_picker.dart';
import 'package:streak/features/settings/state/graph_color_overrides_controller.dart';

/// Small palette icon that lets the user override the color of a
/// single analytical widget. Renders as a tinted chip showing the
/// current effective color — Material You accent when no override is
/// set, the custom color when one is.
///
/// Tapping opens the [GraphColorOverrideSheet] which reuses
/// [FullSpectrumColorPicker] from Phase 1. Long-pressing the button
/// instantly resets to the Material You default.
class GraphColorOverrideButton extends StatelessWidget {
  const GraphColorOverrideButton({
    super.key,
    required this.graphId,
    required this.defaultColor,
    this.tooltip,
  });

  /// Stable graph id from [GraphColorOverridesController] (e.g.
  /// [GraphColorOverridesController.focusRangeBars]).
  final String graphId;

  /// Color used when no override is set — typically the Material You
  /// accent resolved by the parent.
  final Color defaultColor;

  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final overrides = context.watch<GraphColorOverridesController>();
    final override = overrides.overrideFor(graphId);
    final effective = override ?? defaultColor;
    final hasOverride = override != null;

    return Semantics(
      button: true,
      label: tooltip ?? context.l10n.focus_graph_color_title,
      child: GestureDetector(
        onTap: () => _open(context, overrides, effective),
        onLongPress: () => overrides.clearOverride(graphId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: effective.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: effective.withValues(alpha: hasOverride ? 1.0 : 0.4),
              width: hasOverride ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasOverride ? LucideIcons.palette : LucideIcons.palette,
                size: 13,
                color: effective,
              ),
              const SizedBox(width: 5),
              Text(
                hasOverride
                    ? context.l10n.focus_graph_color_custom
                    : context.l10n.focus_graph_color_reset,
                style: sheetLabelStyle(
                  context,
                  size: 11,
                  color: effective,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    GraphColorOverridesController controller,
    Color initial,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => GraphColorOverrideSheet(
        graphId: graphId,
        initial: initial,
        controller: controller,
      ),
    );
  }
}

class GraphColorOverrideSheet extends StatefulWidget {
  const GraphColorOverrideSheet({
    super.key,
    required this.graphId,
    required this.initial,
    required this.controller,
  });

  final String graphId;
  final Color initial;
  final GraphColorOverridesController controller;

  @override
  State<GraphColorOverrideSheet> createState() =>
      _GraphColorOverrideSheetState();
}

class _GraphColorOverrideSheetState extends State<GraphColorOverrideSheet> {
  late Color _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  Future<void> _save() async {
    await widget.controller.setOverride(widget.graphId, _picked);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await widget.controller.clearOverride(widget.graphId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                context.l10n.focus_graph_color_title,
                subtitle: context.l10n.focus_graph_color_custom,
              ),
              const SizedBox(height: 18),
              FullSpectrumColorPicker(
                selected: _picked,
                onChanged: (c) => setState(() {
                  _picked = c;
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: Icon(LucideIcons.rotateCcw, size: 16),
                      label: Text(context.l10n.focus_graph_color_reset),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: Icon(LucideIcons.check, size: 16),
                      label: Text(context.l10n.save),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
