import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/focus/data/focus_timeframe_stats.dart';

/// Three-state chip bar that toggles the Focus Stats screen between
/// 30-day, 90-day, and all-time rolling windows. When no timeframe is
/// active, the page falls back to the legacy week/month/year view.
///
/// The chips paint with the label's color (the active theme accent by
/// default) when selected — matching the Material You chip language
/// established by [FocusLabelChip] and the timer-style picker.
class TimeframeFilterChipBar extends StatelessWidget {
  const TimeframeFilterChipBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accent,
  });

  /// Currently-active timeframe, or `null` when the legacy
  /// week/month/year view is active.
  final FocusTimeframe? selected;
  final ValueChanged<FocusTimeframe?> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tint = accent ?? scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
          child: Text(
            context.l10n.focus_timeframe_section,
            style: sheetLabelStyle(
              context,
              size: 12.5,
              color: context.tokens.muted,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TimeframeChip(
              label: context.l10n.focus_timeframe_off,
              icon: LucideIcons.calendarDays,
              selected: selected == null,
              tint: tint,
              onTap: () => onChanged(null),
            ),
            _TimeframeChip(
              label: context.l10n.focus_timeframe_30d,
              icon: LucideIcons.calendarRange,
              selected: selected == FocusTimeframe.last30Days,
              tint: tint,
              onTap: () => onChanged(FocusTimeframe.last30Days),
            ),
            _TimeframeChip(
              label: context.l10n.focus_timeframe_90d,
              icon: LucideIcons.calendarRange,
              selected: selected == FocusTimeframe.last90Days,
              tint: tint,
              onTap: () => onChanged(FocusTimeframe.last90Days),
            ),
            _TimeframeChip(
              label: context.l10n.focus_timeframe_all,
              icon: LucideIcons.infinity,
              selected: selected == FocusTimeframe.allTime,
              tint: tint,
              onTap: () => onChanged(FocusTimeframe.allTime),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeframeChip extends StatelessWidget {
  const _TimeframeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? tint.withValues(alpha: 0.18)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? tint : Colors.transparent,
              width: 1.3,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected
                    ? (tint.computeLuminance() > 0.55
                        ? const Color(0xFF1C1C1E)
                        : tint)
                    : context.tokens.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: sheetLabelStyle(
                  context,
                  size: 12.5,
                  color: selected
                      ? (tint.computeLuminance() > 0.55
                          ? const Color(0xFF1C1C1E)
                          : tint)
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
