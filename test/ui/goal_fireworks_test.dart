import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/models/beer.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:beer_count/ui/widgets/goal_fireworks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_beer_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A Sunday, and weeks start on Sunday by default.
  final now = DateTime(2026, 9, 20, 21, 30);
  late BeerRepository repo;
  late SettingsStore settings;

  Future<void> setUpWith({
    Map<String, Object> prefs = const {},
    List<Beer> seed = const [],
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsStore.kWeeklyGoal: 2,
      ...prefs,
    });
    repo = BeerRepository(
      log: InMemoryBeerLog(seed: seed),
      widget: const NoopWidgetBridge(),
      clock: () => now,
    );
    settings = SettingsStore();
    await settings.load();
    await repo.load();
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BeerRepository>.value(value: repo),
          ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: GoalCelebration(
            clock: () => now,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final fireworks = find.byType(GoalFireworks);

  testWidgets('reaching the goal fires once, then clears', (tester) async {
    await setUpWith();
    await pump(tester);
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 18));
    await tester.pump();
    expect(fireworks, findsNothing);

    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 19));
    await tester.pump();
    expect(fireworks, findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(settings.celebratedGoal, '2026-09-20#2');

    await tester.pumpAndSettle();
    expect(fireworks, findsNothing);

    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 20));
    await tester.pump();
    expect(fireworks, findsNothing, reason: 'once per week, not per beer');
  });

  testWidgets('a goal reached from the widget fires on open', (tester) async {
    await setUpWith(
      seed: [
        Beer(id: 'a', ml: 500, at: DateTime(2026, 9, 20, 12)),
        Beer(id: 'b', ml: 500, at: DateTime(2026, 9, 20, 13)),
      ],
    );
    await pump(tester);
    expect(fireworks, findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('an already celebrated week stays quiet', (tester) async {
    await setUpWith(
      prefs: {SettingsStore.kCelebratedGoal: '2026-09-20#2'},
      seed: [
        Beer(id: 'a', ml: 500, at: DateTime(2026, 9, 20, 12)),
        Beer(id: 'b', ml: 500, at: DateTime(2026, 9, 20, 13)),
      ],
    );
    await pump(tester);
    expect(fireworks, findsNothing);
  });

  testWidgets('last week does not count toward this one', (tester) async {
    await setUpWith(
      seed: [
        Beer(id: 'a', ml: 500, at: DateTime(2026, 9, 19, 12)),
        Beer(id: 'b', ml: 500, at: DateTime(2026, 9, 20, 13)),
      ],
    );
    await pump(tester);
    expect(fireworks, findsNothing);
  });

  testWidgets('a goal of zero never fires', (tester) async {
    await setUpWith(
      prefs: {SettingsStore.kWeeklyGoal: 0},
      seed: [Beer(id: 'a', ml: 500, at: DateTime(2026, 9, 20, 12))],
    );
    await pump(tester);
    expect(fireworks, findsNothing);
  });

  testWidgets('raising the goal and reaching it again fires again',
      (tester) async {
    await setUpWith(
      prefs: {SettingsStore.kCelebratedGoal: '2026-09-20#2'},
      seed: [
        Beer(id: 'a', ml: 500, at: DateTime(2026, 9, 20, 12)),
        Beer(id: 'b', ml: 500, at: DateTime(2026, 9, 20, 13)),
      ],
    );
    await pump(tester);
    await settings.setWeeklyGoal(3);
    await tester.pump();
    expect(fireworks, findsNothing);

    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 14));
    await tester.pump();
    expect(fireworks, findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('never blocks taps on the app underneath', (tester) async {
    await setUpWith(
      seed: [
        Beer(id: 'a', ml: 500, at: DateTime(2026, 9, 20, 12)),
        Beer(id: 'b', ml: 500, at: DateTime(2026, 9, 20, 13)),
      ],
    );
    var taps = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BeerRepository>.value(value: repo),
          ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ],
        child: MaterialApp(
          home: GoalCelebration(
            clock: () => now,
            child: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('under'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(fireworks, findsOneWidget);
    await tester.tap(find.text('under'), warnIfMissed: false);
    expect(taps, 1);
    await tester.pumpAndSettle();
  });
}
