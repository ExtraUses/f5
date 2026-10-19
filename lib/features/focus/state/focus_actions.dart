import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/routing/app_navigator.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/services/focus_service.dart';

Future<void> applyFocusAction(FocusAction action) async {
  final context = AppNavigator.key.currentContext;
  if (context == null) return;

  final focus = context.read<FocusController>();
  if (!focus.isActive) return;

  final habits = context.read<HabitsController>();
  final habitId = focus.habitId;
  final session = await focus.apply(action);
  if (session == null || habitId.isEmpty) return;

  await _creditPrimary(habits, focus, session, habitId);
  await _creditLinked(habits, focus, session);
}

Future<void> creditFocusRound(
  HabitsController habits,
  FocusController focus,
  FocusSession session,
) async {
  await _creditPrimary(habits, focus, session, session.habitId);
  await _creditLinked(habits, focus, session);
}

/// Convenience wrapper used by [FocusPage._confirmStop] — applies both
/// the primary and linked completion credits in one call.
Future<void> creditFocusSession(
  HabitsController habits,
  FocusController focus,
  FocusSession? session,
) async {
  if (session == null) return;
  await creditFocusRound(habits, focus, session);
}

/// Reverses every credit applied to a session — both primary and linked.
/// Used by the focus history page when the user deletes a session.
/// Idempotent: positive-habit toggles are NOT auto-reversed (the user
/// may have manually re-toggled after the focus credit); we only
/// reverse the minute-credit on time-amount habits, since that credit
/// is purely numeric and never user-visible as a binary "done" state.
Future<void> reverseFocusCredits(
  HabitsController habits,
  FocusController focus,
  FocusSession session,
) async {
  await countFocusTime(habits, focus, session, undo: true);
  if (session.linkedHabitIds.isEmpty) return;
  for (final linkedId in session.linkedHabitIds) {
    if (linkedId.isEmpty || linkedId == session.habitId) continue;
    final habit = habits.byId(linkedId);
    if (habit == null || !habit.isTimeAmount) continue;
    for (final piece in session.split()) {
      final minutes = piece.seconds / 60;
      await habits.addProgress(
        habit.id,
        piece.countedOn,
        -minutes,
      );
    }
  }
}

/// Applies a focus-completion credit to the primary habit attached to the
/// session. This is the legacy behavior — preserved verbatim so existing
/// tests and analytics stay green.
Future<void> _creditPrimary(
  HabitsController habits,
  FocusController focus,
  FocusSession session,
  String habitId,
) async {
  final habit = habits.byId(habitId);
  if (habit == null) return;

  if (habit.isTimeAmount) {
    await countFocusTime(habits, focus, session);
    return;
  }

  final today = AppClock.now();
  if (!session.completed || habit.kind != HabitKind.positive) return;
  if (habit.isCompletedOn(today)) return;
  await habits.toggle(habit.id, today, fromFocus: true);
}

/// Walks the session's [FocusSession.linkedHabitIds] and writes a full
/// completion credit to each tagged habit.
///
/// Per the Phase 2 spec decision:
///   * Time-amount habits receive minute-credit via [HabitsController.addProgress].
///   * Positive habits receive a full `toggle(id, today, fromFocus: true)`.
///   * Idempotent — already-completed habits are skipped, so re-crediting
///     a session that was re-saved after a migration doesn't double-count.
///   * The primary habit is explicitly skipped here because [_creditPrimary]
///     already handled it; this also defends against a session that
///     accidentally lists its own primary habit in `linkedHabitIds`.
Future<void> _creditLinked(
  HabitsController habits,
  FocusController focus,
  FocusSession session,
) async {
  if (session.linkedHabitIds.isEmpty) return;
  final today = AppClock.now();
  for (final linkedId in session.linkedHabitIds) {
    if (linkedId.isEmpty || linkedId == session.habitId) continue;
    final habit = habits.byId(linkedId);
    if (habit == null) continue;

    if (habit.isTimeAmount) {
      await _creditTimeAmountLinked(habits, focus, session, habit);
      continue;
    }
    if (!session.completed) continue;
    if (habit.kind != HabitKind.positive) continue;
    if (habit.isCompletedOn(today)) continue;
    await habits.toggle(habit.id, today, fromFocus: true);
  }
}

/// Mirrors [countFocusTime] but bound to a *linked* habit rather than the
/// session's primary habit. Splits the session at midnight boundaries
/// (same as the primary path) so multi-day sessions credit each day's
/// correct date.
Future<void> _creditTimeAmountLinked(
  HabitsController habits,
  FocusController focus,
  FocusSession session,
  Habit habit,
) async {
  for (final piece in session.split()) {
    final minutes = piece.seconds / 60;
    await habits.addProgress(
      habit.id,
      piece.countedOn,
      minutes,
    );
  }
}

Future<void> countFocusTime(
  HabitsController habits,
  FocusController focus,
  FocusSession session, {
  bool undo = false,
}) async {
  final habit = habits.byId(session.habitId);
  if (habit == null || !habit.isTimeAmount) return;
  if (undo && !session.counted) return;
  for (final piece in session.split()) {
    final minutes = piece.seconds / 60;
    await habits.addProgress(
      habit.id,
      piece.countedOn,
      undo ? -minutes : minutes,
    );
    if (!undo) await focus.markCounted(piece.id);
  }
}

Future<void> drainFocusActions() async {
  if (AppNavigator.key.currentContext == null) return;
  for (final action in await FocusService.drain()) {
    await applyFocusAction(action);
  }
}
