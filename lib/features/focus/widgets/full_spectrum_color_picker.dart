import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as cp;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_palette.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/sheet_type.dart';

/// Full-bandwidth HSV color picker for focus labels.
///
/// Replaces the static preset palette used elsewhere in the app with three
/// complementary inputs that always agree:
///
///  * [cp.HueRingPicker] — large ring + inner HSV square for fine control.
///  * An HSV slider row (saturation + value) — for users who prefer sliders.
///  * A hex text field — for power users who already know the color they want.
///
/// Material You compliance: when the user has not picked a custom color yet,
/// the picker seeds itself from [ThemeData.colorScheme.primary] so the
/// initial state visually belongs to the user's active dynamic theme.
class FullSpectrumColorPicker extends StatefulWidget {
  const FullSpectrumColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.heading,
  });

  final Color selected;
  final ValueChanged<Color> onChanged;
  final String? heading;

  @override
  State<FullSpectrumColorPicker> createState() =>
      _FullSpectrumColorPickerState();
}

class _FullSpectrumColorPickerState extends State<FullSpectrumColorPicker> {
  late TextEditingController _hex;
  late FocusNode _hexFocus;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _hex = TextEditingController(text: _hexOf(widget.selected));
    _hexFocus = FocusNode();
    _hexFocus.addListener(_onHexFocusChanged);
  }

  @override
  void didUpdateWidget(covariant FullSpectrumColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected && !_hexFocus.hasFocus) {
      _syncing = true;
      _hex.text = _hexOf(widget.selected);
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _hexFocus.removeListener(_onHexFocusChanged);
    _hexFocus.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _onHexFocusChanged() {
    if (!_hexFocus.hasFocus) {
      // When the field loses focus, snap it back to the canonical hex.
      _syncing = true;
      _hex.text = _hexOf(widget.selected);
      _syncing = false;
    }
  }

  String _hexOf(Color c) {
    final v = c.toARGB32();
    final hex = (v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    return '#$hex';
  }

  void _emit(Color c) {
    if (c.toARGB32() == widget.selected.toARGB32()) return;
    if (!_syncing) {
      _syncing = true;
      _hex.text = _hexOf(c);
      _syncing = false;
    }
    widget.onChanged(c);
  }

  void _onHexFieldChanged(String value) {
    if (_syncing) return;
    final parsed = _parseHex(value);
    if (parsed != null) _emit(parsed);
  }

  static Color? _parseHex(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) {
      // Expand "abc" → "aabbcc"
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.heading != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              widget.heading!,
              style: sheetLabelStyle(
                context,
                size: 13,
                color: tokens.muted,
              ),
            ),
          ),
        ],
        // Ring + square picker.
        Center(
          child: cp.HueRingPicker(
            pickerColor: widget.selected,
            onColorChanged: _emit,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        const SizedBox(height: 14),
        // HSV slider row — saturation and value.
        // Using the lower-level `ColorPicker` would couple us to its
        // ever-shifting param list, so we expose hue via the ring and
        // saturation/value via two Material sliders driven off HSV.
        _HsvSliderRow(
          color: widget.selected,
          onChanged: _emit,
        ),
        const SizedBox(height: 14),
        // Hex field row.
        Row(
          children: [
            _HexPreview(color: widget.selected),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hex,
                focusNode: _hexFocus,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '',
                  labelText: context.l10n.custom,
                  hintText: '#7C3AED',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 15,
                  letterSpacing: 0.4,
                  color: scheme.onSurface,
                ),
                onChanged: _onHexFieldChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _QuickPalette(
          selected: widget.selected,
          onSelected: _emit,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _emit(scheme.primary),
                icon: Icon(LucideIcons.palette, size: 16),
                label: Text(context.l10n.colors_tab),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _emit(AppPalette.brand),
                icon: Icon(LucideIcons.flame, size: 16),
                label: Text(context.l10n.save),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HexPreview extends StatelessWidget {
  const _HexPreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blends =
        (color.computeLuminance() - scheme.surface.computeLuminance())
            .abs() < 0.1;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: blends
            ? Border.all(color: scheme.onSurface.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _QuickPalette extends StatelessWidget {
  const _QuickPalette({required this.selected, required this.onSelected});

  final Color selected;
  final ValueChanged<Color> onSelected;

  static const _spots = <Color>[
    Color(0xFF7C3AED),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C853),
    Color(0xFF5AC8FA),
    Color(0xFF0A84FF),
    Color(0xFF5856D6),
    Color(0xFFBF5AF2),
    Color(0xFFFF2D92),
    Color(0xFF8E8E93),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 6;
        const spacing = 8.0;
        final swatch =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                .clamp(28.0, 44.0);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final color in _spots)
              _Spot(
                color: color,
                size: swatch,
                selected:
                    selected.toARGB32() == color.toARGB32(),
                onTap: () => onSelected(color),
              ),
          ],
        );
      },
    );
  }
}

class _Spot extends StatelessWidget {
  const _Spot({
    required this.color,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checkColor = color.computeLuminance() > 0.6
        ? const Color(0xFF1C1C1E)
        : Colors.white;
    final borderColor = color.computeLuminance() > 0.85
        ? const Color(0xFF8E8E93)
        : Colors.white;
    final blends = (color.computeLuminance() - scheme.surface.computeLuminance())
        .abs() < 0.1;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: borderColor, width: 2.5)
                : blends
                    ? Border.all(
                        color: scheme.onSurface.withValues(alpha: 0.3))
                    : null,
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)]
                : null,
          ),
          child: selected
              ? Icon(LucideIcons.check, color: checkColor, size: 18)
              : null,
        ),
      ),
    );
  }
}

/// Saturation + value sliders driven off the HSV color space.
///
/// Independent of any [flutter_colorpicker] API drift — built from the
/// stock Material [Slider] widget. Hue is controlled by the
/// [cp.HueRingPicker] above; these two sliders give the user fine
/// control over saturation and brightness.
class _HsvSliderRow extends StatelessWidget {
  const _HsvSliderRow({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  HSVColor get _hsv => HSVColor.fromColor(color);

  @override
  Widget build(BuildContext context) {
    final hsv = _hsv;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SliderRow(
          label: 'S',
          value: hsv.saturation,
          activeColor: color,
          trackColor: scheme.surfaceContainerHighest,
          onChanged: (s) => onChanged(hsv.withSaturation(s).toColor()),
        ),
        const SizedBox(height: 4),
        _SliderRow(
          label: 'V',
          value: hsv.value,
          activeColor: color,
          trackColor: scheme.surfaceContainerHighest,
          onChanged: (v) => onChanged(hsv.withValue(v).toColor()),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.trackColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color activeColor;
  final Color trackColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: trackColor,
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.18),
              activeTickMarkColor: activeColor,
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
