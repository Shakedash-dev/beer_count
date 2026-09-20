import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:beer_count/ui/timeline_screen.dart';
import 'package:beer_count/ui/widgets/journey_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_beer_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryBeerLog store;
  late BeerRepository repo;
  late SettingsStore settings;
  final now = DateTime(2026, 9, 20, 21, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = InMemoryBeerLog();
    repo = BeerRepository(
      log: store,
      widget: const NoopWidgetBridge(),
      clock: () => now,
    );
    settings = SettingsStore();
    await settings.load();
    await repo.load();
  });

  Future<void> pump(WidgetTester tester) async {
    // Wide and tall enough that the whole journey is laid out at once.
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BeerRepository>.value(value: repo),
          ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: TimelineScreen(now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty log shows the journey start state', (tester) async {
    await pump(tester);
    expect(find.text('THE JOURNEY STARTS HERE'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('NOW'), findsNothing);
  });

  testWidgets('tapping the 1/3 button logs exactly one beer', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('log-third')));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1));
    expect(repo.beers.single.ml, 333);
  });

  testWidgets('tapping the 1/2 button logs a 500ml beer', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('log-half')));
    await tester.pumpAndSettle();
    expect(repo.beers.single.ml, 500);
  });

  testWidgets('hero block shows today count and litres', (tester) async {
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 18));
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 19));
    await pump(tester);
    expect(find.text('2'), findsWidgets);
    expect(find.textContaining('1.0 L'), findsWidgets);
  });

  testWidgets('goal bar reflects the weekly goal and hides when zero',
      (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    expect(find.text('1 / 14'), findsOneWidget);

    await settings.setWeeklyGoal(0);
    await tester.pumpAndSettle();
    expect(find.text('THIS WEEK'), findsNothing);
  });

  group('the journey', () {
    testWidgets('renders one waypoint per beer, labelled by local time',
        (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 9, 5));
      await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 18, 40));
      await pump(tester);
      expect(find.text('09:05'), findsOneWidget);
      expect(find.text('18:40'), findsOneWidget);
      expect(find.text('½'), findsWidgets);
      expect(find.text('⅓'), findsWidgets);
    });

    testWidgets('runs oldest to newest, left to right', (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 19, 20));
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 20));
      await pump(tester);
      expect(
        tester.getCenter(find.text('YESTERDAY')).dx,
        lessThan(tester.getCenter(find.text('TODAY')).dx),
      );
    });

    testWidgets('marks each day with its own count and volume',
        (tester) async {
      await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 18));
      await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 19));
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 14, 20));
      await pump(tester);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('MON 14 SEP'), findsOneWidget);
      expect(find.text('2 · 1.0 L'), findsOneWidget);
      expect(find.text('1 · 0.3 L'), findsOneWidget);
    });

    testWidgets('ends with a NOW cap', (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      expect(find.text('NOW'), findsOneWidget);
    });

    testWidgets('shows only a recent window of a long history',
        (tester) async {
      for (var i = 0; i < maxWaypoints + 12; i++) {
        await repo.addAt(
          ml: 333,
          at: DateTime(2026, 9, 20, 8).subtract(Duration(minutes: i)),
        );
      }
      await pump(tester);
      expect(find.text('12'), findsWidgets);
      expect(find.text('more'), findsOneWidget);
    });
  });

  group('deleting a mis-tapped beer', () {
    testWidgets('tapping a waypoint opens its detail sheet', (tester) async {
      await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      await tester.tap(find.text('18:00'));
      await tester.pumpAndSettle();
      expect(find.text('500 ml'), findsOneWidget);
      expect(find.text('DELETE THIS BEER'), findsOneWidget);
      expect(find.text('KEEP IT'), findsOneWidget);
    });

    testWidgets('confirming removes it and offers undo', (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      await tester.tap(find.text('18:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE THIS BEER'));
      await tester.pumpAndSettle();

      expect(repo.beers, isEmpty);
      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      expect(repo.beers, hasLength(1));
    });

    testWidgets('keeping it changes nothing', (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      await tester.tap(find.text('18:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KEEP IT'));
      await tester.pumpAndSettle();
      expect(repo.beers, hasLength(1));
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      await tester.tap(find.text('18:00'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(repo.beers, hasLength(1));
    });
  });
}
