import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/ui/settings_screen.dart';
import 'package:beer_count/ui/theme.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = InMemoryBeerLog();
    repo = BeerRepository(
      log: store,
      widget: const NoopWidgetBridge(),
      clock: () => DateTime(2026, 9, 20, 21),
    );
    settings = SettingsStore();
    await settings.load();
    await repo.load();
  });


  Future<void> pump(WidgetTester tester) async {
    // Tall viewport so the lazy ListView builds every card at once.
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BeerRepository>.value(value: repo),
          ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ],
        child: MaterialApp(theme: buildTheme(), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the current goal and week start', (tester) async {
    await pump(tester);
    expect(find.text('14 beers'), findsOneWidget);
    expect(find.text('WEEK STARTS ON'), findsOneWidget);
  });

  testWidgets('a zero goal reads as off', (tester) async {
    await settings.setWeeklyGoal(0);
    await pump(tester);
    expect(find.text('off'), findsOneWidget);
  });

  testWidgets('switching the week start persists it', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();
    expect(settings.weekStartWeekday, DateTime.monday);
  });

  testWidgets('shows the entry count', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    expect(find.text('1 entries'), findsOneWidget);
  });

  testWidgets('erase requires confirmation', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);

    await tester.tap(find.text('ERASE ALL DATA'));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1), reason: 'not erased before confirming');

    await tester.tap(find.text('ERASE'));
    await tester.pumpAndSettle();
    expect(repo.beers, isEmpty);
  });

  testWidgets('cancelling the erase dialog keeps the data', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    await tester.tap(find.text('ERASE ALL DATA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1));
  });

  testWidgets('skipped lines are surfaced only when present', (tester) async {
    await pump(tester);
    expect(find.textContaining('skipped'), findsNothing);
  });

  testWidgets('skipped lines are shown when the log has damage',
      (tester) async {
    store.skippedLines = 1;
    await repo.load();
    await pump(tester);
    expect(find.text('1 unreadable lines skipped'), findsOneWidget);
  });
}
