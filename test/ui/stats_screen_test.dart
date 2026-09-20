import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/ui/stats_screen.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:beer_count/ui/widgets/bar_chart.dart';
import 'package:beer_count/ui/widgets/heatmap.dart';
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
        child: MaterialApp(theme: buildTheme(), home: StatsScreen(now: now)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every section with an empty log', (tester) async {
    await pump(tester);
    for (final title in const [
      'TODAY',
      'THIS WEEK',
      'ALL TIME',
      'RHYTHM',
      'STREAKS',
      'MIX',
      'YEAR',
    ]) {
      expect(find.text(title), findsWidgets, reason: 'missing $title');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows totals for a populated log', (tester) async {
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 18));
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 20));
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 14, 20));
    await pump(tester);
    expect(find.textContaining('1.3 L'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('renders the year heatmap with 371 cells', (tester) async {
    await pump(tester);
    expect(tester.widget<Heatmap>(find.byType(Heatmap)).days, hasLength(371));
  });

  testWidgets('renders weekday, hour and 30-day charts', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    final charts = tester.widgetList<BarChart>(find.byType(BarChart)).toList();
    expect(charts.length, greaterThanOrEqualTo(3));
    expect(charts.any((c) => c.values.length == 7), isTrue);
    expect(charts.any((c) => c.values.length == 24), isTrue);
    expect(charts.any((c) => c.values.length == 30), isTrue);
  });

  testWidgets('bar chart survives all-zero input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: BarChart(
            values: List<double>.filled(7, 0),
            labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the peak hour when there is data', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 21));
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 19, 21));
    await pump(tester);
    expect(find.text('21:00'), findsWidgets);
  });

  testWidgets('shows the size mix percentages', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 19));
    await pump(tester);
    expect(find.textContaining('50%'), findsWidgets);
  });

  testWidgets('weekday axis rotates with the week start', (tester) async {
    await settings.setWeekStartWeekday(DateTime.monday);
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    final weekday = tester
        .widgetList<BarChart>(find.byType(BarChart))
        .firstWhere((c) => c.values.length == 7);
    expect(weekday.labels.first, 'M');
    expect(weekday.labels.last, 'S');
  });
}
