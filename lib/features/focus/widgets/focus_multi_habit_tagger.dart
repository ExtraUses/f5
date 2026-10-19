import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/color_extensions.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/habits/state/habits_controller.dart';

/// Multi-select chip row that lets a focus session optionally tag
/// additional habits.
///
/// Writing to [FocusSession.linkedHabitIds] does **not** mutate the
/// primary label assignment. When the session ends, each tagged habit
/// receives a **full** completion credit (per the user's spec decision
/// in Phase 2 clarifications) — identical to a primary completion.
///
/// The primary habit is deliberately excluded from the chip list so a
/// session can't double-count a single habit.
class FocusMultiHabitTagger extends StatelessWidget {
  const FocusMultiHabitTagger({
    super.key,
    required this.primaryHabitId,
    required this.selected,
    required this.onChanged,
  });

  /// The habit the focus session "belongs to" (legacy contract). It is
  /// hidden from the chip list so the user cannot tag the primary
  /// habit twice.
  final String primaryHabitId;

  /// The currently-tagged habit ids.
  final Set<String> selected;

  /// Notifies the parent of a change in the selected set.
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitsController>().habits;
    // Only show positive and time-amount habits — counter habits don't
    // benefit from a focus completion. Hide archived habits too so the
    // row stays compact.
    final today = AppClock.now();
    final candidates = habits.where((h) {
      if (h.id == primaryHabitId) return false;
      if (h.isArchived) return false;
      if (!h.isTimeAmount && h.kind != HabitKind.positive) return false;
      // Already-completed non-time-amount habits are still listable so the
      // user can re-tag them; the credit layer is idempotent.
      return true;
    }).toList()
      ..sort((a, b) {
        // Sort: time-amount habits first (they accumulate credit), then
        // alphabetically.
        final at = a.isTimeAmount ? 0 : 1;
        final bt = b.isTimeAmount ? 0 : 1;
        if (at != bt) return at.compareTo(bt);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (candidates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
          child: Row(
            children: [
              Icon(
                LucideIcons.plus,
                size: 14,
                color: context.tokens.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.focus_linked_habits,
                  style: sheetLabelStyle(
                    context,
                    size: 13,
                    color: context.tokens.muted,
                  ),
                ),
              ),
              if (selected.isNotEmpty)
                GestureDetector(
                  onTap: () => onChanged(const {}),
                  child: Text(
                    context.l10n.focus_linked_habits_none,
                    style: sheetLabelStyle(
                      context,
                      size: 12,
                      color: context.colors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (selected.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Text(
              context.l10n.focus_linked_habits_hint,
              style: sheetLabelStyle(
                context,
                size: 12.5,
                color: context.tokens.muted,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final habit in candidates.take(8))
                _HabitTagChip(
                  habit: habit,
                  selected: selected.contains(habit.id),
                  alreadyCompletedToday:
                      !habit.isTimeAmount && habit.isCompletedOn(today),
                  onTap: () {
                    final next = Set<String>.of(selected);
                    if (!next.add(habit.id)) next.remove(habit.id);
                    onChanged(next);
                  },
                ),
            ],
          ),
        const SizedBox(height: 4),
        // Show overflow count if there are more than 8 candidates.
        if (candidates.length > 8)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
            child: Text(
              '+${candidates.length - 8}',
              style: sheetLabelStyle(
                context,
                size: 11,
                color: context.tokens.muted,
              ),
            ),
          ),
      ],
    );
  }
}

class _HabitTagChip extends StatelessWidget {
  const _HabitTagChip({
    required this.habit,
    required this.selected,
    required this.alreadyCompletedToday,
    required this.onTap,
  });

  final Habit habit;
  final bool selected;
  final bool alreadyCompletedToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final accent = habit.color.shownIn(context);
    final checkColor = accent.computeLuminance() > 0.6
        ? const Color(0xFF1C1C1E)
        : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: habit.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.18)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 1.3,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(LucideIcons.check, size: 12, color: checkColor),
                const SizedBox(width: 5),
              ] else if (alreadyCompletedToday) ...[
                Icon(
                  LucideIcons.circleCheck,
                  size: 12,
                  color: context.tokens.success.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sheetLabelStyle(
                  context,
                  size: 12.5,
                  color: selected
                      ? (accent.computeLuminance() > 0.55
                          ? const Color(0xFF1C1C1E)
                          : accent)
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
