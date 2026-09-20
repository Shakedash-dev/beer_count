import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:beer_count/ui/timeline_screen.dart';
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

  testWidgets('empty log shows the empty state and no day headers',
      (tester) async {
    await pump(tester);
    expect(find.text('NO BEERS YET'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('tapping the 1/3 button logs exactly one beer', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('log-third')));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1));
    expect(repo.beers.single.ml, 333);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('tapping the 1/2 button logs a 500ml beer', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('log-half')));
    await tester.pumpAndSettle();
    expect(repo.beers.single.ml, 500);
  });

  testWidgets('groups entries under day headers, newest day first',
      (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 19, 20));
    await pump(tester);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('TODAY')).dy,
      lessThan(tester.getTopLeft(find.text('YESTERDAY')).dy),
    );
  });

  testWidgets('shows today count and litres in the hero block',
      (tester) async {
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

  testWidgets('swiping an entry deletes it and offers undo', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    await tester.drag(find.text('18:00'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(repo.beers, isEmpty);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1));
  });

  testWidgets('entry rows show local time and size glyph', (tester) async {
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 9, 5));
    await pump(tester);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('½'), findsWidgets);
  });

  testWidgets('an older day gets a dated header', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 14, 20));
    await pump(tester);
    expect(find.text('MON 14 SEP'), findsOneWidget);
  });
}
