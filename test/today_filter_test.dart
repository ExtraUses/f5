import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/features/habits/pages/home_page.dart';
import 'package:streak/features/habits/widgets/today_filter_sheet.dart';

import 'support/app_harness.dart';

void main() {
  useEmptyStore();

  testWidgets('hiding completed leaves only what is still to do', (
    tester,
  ) async {
    await seedHabits(tester, [
      testHabit(id: 'a', name: 'Run', order: 0, done: lastDays(1)),
      testHabit(id: 'b', name: 'Read', order: 1),
    ]);
    await pumpScreen(tester, const HomePage(), settings: {'hideDone': true});

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Run'), findsNothing);
    expect(find.byType(TodayAllDone), findsNothing);
  });

  testWidgets('with everything done it says so instead of an empty list', (
    tester,
  ) async {
    await seedHabits(tester, [
      testHabit(id: 'a', name: 'Run', done: lastDays(1)),
    ]);
    await pumpScreen(tester, const HomePage(), settings: {'hideDone': true});

    expect(find.text('Run'), findsNothing);
    expect(find.byType(TodayAllDone), findsOneWidget);
  });

  testWidgets('the filter button reaches both switches from Today', (
    tester,
  ) async {
    await seedHabits(tester, [testHabit(id: 'a', name: 'Run')]);
    await pumpScreen(tester, const HomePage());

    await tester.tap(find.byIcon(LucideIcons.listFilter));
    await tester.pumpAndSettle();

    expect(find.text("Only today's"), findsOneWidget);
    expect(find.text('Hide completed'), findsOneWidget);
  });
}
