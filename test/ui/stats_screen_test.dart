import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/ui/stats_screen.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:beer_count/ui/widgets/charts/arc_gauge.dart';
import 'package:beer_count/ui/widgets/charts/donut_chart.dart';
import 'package:beer_count/ui/widgets/charts/radial_hours.dart';
import 'package:beer_count/ui/widgets/charts/sparkline.dart';
import 'package:beer_count/ui/widgets/charts/streak_ribbon.dart';
import 'package:beer_count/ui/widgets/charts/weekday_radar.dart';
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
      'THIS WEEK',
      'LAST 30 DAYS',
      'BY HOUR',
      'BY WEEKDAY',
      'STREAKS',
      'MIX',
      'ALL TIME',
      'YEAR',
    ]) {
      expect(find.text(title), findsWidgets, reason: 'missing $title');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every diagram is drawn even with no data', (tester) async {
    await pump(tester);
    expect(find.byType(ArcGauge), findsOneWidget);
    expect(find.byType(Sparkline), findsOneWidget);
    expect(find.byType(RadialHours), findsOneWidget);
    expect(find.byType(WeekdayRadar), findsOneWidget);
    expect(find.byType(StreakRibbon), findsOneWidget);
    expect(find.byType(DonutChart), findsOneWidget);
    expect(find.byType(Heatmap), findsOneWidget);
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

  group('the weekly gauge', () {
    testWidgets('is drawn against the goal', (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      final gauge = tester.widget<ArcGauge>(find.byType(ArcGauge));
      expect(gauge.value, 1);
      expect(gauge.max, 14);
      expect(gauge.over, isFalse);
      expect(find.text('OF 14'), findsOneWidget);
    });

    testWidgets('flips to over when the week exceeds the goal',
        (tester) async {
      await settings.setWeeklyGoal(2);
      for (var i = 0; i < 3; i++) {
        await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 12 + i));
      }
      await pump(tester);
      expect(tester.widget<ArcGauge>(find.byType(ArcGauge)).over, isTrue);
    });

    testWidgets('drops the goal caption when the goal is off', (tester) async {
      await settings.setWeeklyGoal(0);
      await pump(tester);
      expect(find.text('BEERS'), findsWidgets);
      expect(find.textContaining('OF '), findsNothing);
    });
  });

  group('the diagrams carry the right series', () {
    testWidgets('sparkline plots 30 days', (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      expect(
        tester.widget<Sparkline>(find.byType(Sparkline)).values,
        hasLength(30),
      );
    });

    testWidgets('hour clock plots 24 spokes and marks the peak',
        (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 21));
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 19, 21));
      await pump(tester);
      final clock = tester.widget<RadialHours>(find.byType(RadialHours));
      expect(clock.countByHour, hasLength(24));
      expect(clock.peakHour, 21);
      expect(find.textContaining('21:00'), findsWidgets);
    });

    testWidgets('radar plots seven weekdays from the week start',
        (tester) async {
      await settings.setWeekStartWeekday(DateTime.monday);
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      final radar = tester.widget<WeekdayRadar>(find.byType(WeekdayRadar));
      expect(radar.values, hasLength(7));
      expect(radar.labels.first, 'MON');
      expect(radar.labels.last, 'SUN');
    });

    testWidgets('streak ribbon covers the last 60 days ending today',
        (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      final ribbon = tester.widget<StreakRibbon>(find.byType(StreakRibbon));
      expect(ribbon.days, hasLength(60));
      expect(ribbon.days.last.day, DateTime(2026, 9, 20));
      expect(ribbon.days.last.count, 1);
      expect(find.text('last 60 days'), findsOneWidget);
    });

    testWidgets('heatmap still covers 371 days', (tester) async {
      await pump(tester);
      expect(tester.widget<Heatmap>(find.byType(Heatmap)).days, hasLength(371));
    });

    testWidgets('donut splits the two sizes', (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 19));
      await pump(tester);
      final donut = tester.widget<DonutChart>(find.byType(DonutChart));
      expect(donut.slices.map((s) => s.value).toList(), [1, 1, 0]);
      expect(find.text('50%'), findsWidgets);
    });
  });

  testWidgets('captions read as sentences, not raw numbers', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 21));
    await pump(tester);
    expect(find.textContaining('Peak hour is'), findsOneWidget);
    expect(find.textContaining('biggest day'), findsOneWidget);
  });
}
