import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/pages/focus_history_page.dart';
import 'package:streak/features/focus/pages/focus_stats_page.dart';
import 'package:streak/features/focus/widgets/color_coded_focus_bars.dart';

import 'support/app_harness.dart';

FocusSession _session({
  required String id,
  required String habitId,
  required DateTime startedAt,
  required int minutes,
}) =>
    FocusSession(
      id: id,
      habitId: habitId,
      targetMinutes: minutes,
      seconds: minutes * 60,
      completed: true,
      startedAt: startedAt,
    );

Future<void> _seedSessions(
  WidgetTester tester,
  List<FocusSession> sessions,
) =>
    tester.runAsync(() async {
      for (final session in sessions) {
        await LocalStore.writeFocusSession(session);
      }
    });

Future<void> _waitFor(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    if (target.evaluate().isNotEmpty) return;
  }
}

void main() {
  useEmptyStore();

  testWidgets('with no sessions it says there is nothing yet', (tester) async {
    await pumpScreen(tester, const FocusStatsPage());

    expect(find.text('No data yet'), findsOneWidget);
    expect(find.byType(ColorCodedFocusBars), findsNothing);
  });

  testWidgets('it totals today, the week, the month and everything',
      (tester) async {
    final today = AppClock.now();
    await seedHabits(tester, [
      testHabit(id: 'a', name: 'Read'),
      testHabit(id: 'b', name: 'Code', order: 1),
    ]);
    await _seedSessions(tester, [
      _session(id: '1', habitId: 'a', startedAt: today, minutes: 30),
      _session(
        id: '2',
        habitId: 'b',
        startedAt: today.subtract(const Duration(days: 1)),
        minutes: 45,
      ),
      _session(
        id: '3',
        habitId: 'a',
        startedAt: today.subtract(const Duration(days: 200)),
        minutes: 60,
      ),
    ]);

    await pumpScreen(tester, const FocusStatsPage());

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('30m'), findsWidgets);
    expect(find.text('2h 15m'), findsOneWidget);
    // The chart is now ColorCodedFocusBars (replaced ValueBars).
    expect(find.byType(ColorCodedFocusBars), findsOneWidget);
  });

  testWidgets('the range switch redraws the chart', (tester) async {
    await _seedSessions(tester, [
      _session(
        id: '1',
        habitId: '',
        startedAt: AppClock.now(),
        minutes: 30,
      ),
    ]);

    await pumpScreen(tester, const FocusStatsPage());
    // Week view shows 7 bars.
    expect(find.byType(ColorCodedFocusBars), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    // Year view still renders the chart (12 months).
    expect(find.byType(ColorCodedFocusBars), findsOneWidget);
  });

  testWidgets('a past session can be logged by hand', (tester) async {
    await pumpScreen(tester, const FocusHistoryPage());
    expect(find.text('No sessions yet'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('Log a session'), findsOneWidget);

    await tester.runAsync(() => tester.tap(find.text('Save')));
    await _waitFor(tester, find.text('Free session'));
    await _waitFor(tester, find.text('25m'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Free session'), findsOneWidget);
    expect(find.text('25m'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
