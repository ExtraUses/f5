import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/habits/pages/home_page.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/habits/widgets/swipe_check.dart';

import 'support/app_harness.dart';

bool _doneToday(WidgetTester tester) => tester
    .element(find.byType(HomePage))
    .read<HabitsController>()
    .byId('a')!
    .isCompletedOn(AppClock.today());

Future<void> _swipe(WidgetTester tester, double dx) async {
  await tester.drag(find.text('Read'), Offset(dx, 0));
  await tester.pumpAndSettle();
}

void main() {
  useEmptyStore();

  for (final minimal in [false, true]) {
    testWidgets(
        'swiping left completes and right undoes (minimal: $minimal)',
        (tester) async {
      await seedHabits(tester, [testHabit(id: 'a', name: 'Read', order: 0)]);
      await pumpScreen(
        tester,
        const HomePage(),
        minimal: minimal,
        settings: {'swipeCards': true},
      );

      await _swipe(tester, 300);
      expect(_doneToday(tester), isFalse);

      await _swipe(tester, -300);
      expect(_doneToday(tester), isTrue);

      await _swipe(tester, -300);
      expect(_doneToday(tester), isTrue);

      await _swipe(tester, 300);
      expect(_doneToday(tester), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('without the setting a swipe does nothing', (tester) async {
    await seedHabits(tester, [testHabit(id: 'a', name: 'Read', order: 0)]);
    await pumpScreen(tester, const HomePage());

    await _swipe(tester, -300);
    expect(_doneToday(tester), isFalse);
    expect(find.byType(SwipeCheck), findsWidgets);
  });
}
