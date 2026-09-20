import 'package:home_widget/home_widget.dart';

import '../models/beer.dart';
import '../stats/buckets.dart';

/// Must match the Kotlin class name of the AppWidgetProvider.
const String kAndroidWidgetName = 'BeerWidgetProvider';

const String kPrefTodayKey = 'today_key';
const String kPrefTodayCount = 'today_count';
const String kPrefTodayMl = 'today_ml';

String formatDayKey(DateTime day) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

/// The tiny cache the home-screen widget renders from. The NDJSON log stays
/// the source of truth; this is recomputed from it on every app load, so a
/// divergence heals itself the next time the app is opened.
class WidgetSummary {
  const WidgetSummary({
    required this.dayKey,
    required this.count,
    required this.ml,
  });

  static const empty = WidgetSummary(dayKey: '', count: 0, ml: 0);

  final String dayKey;
  final int count;
  final int ml;

  @override
  bool operator ==(Object other) =>
      other is WidgetSummary &&
      other.dayKey == dayKey &&
      other.count == count &&
      other.ml == ml;

  @override
  int get hashCode => Object.hash(dayKey, count, ml);

  @override
  String toString() => 'WidgetSummary($dayKey, $count, ${ml}ml)';
}

WidgetSummary summarizeToday(List<Beer> beers, DateTime now) {
  final today = dayKey(now);
  var count = 0;
  var ml = 0;
  for (final beer in beers) {
    if (dayKey(beer.at) != today) continue;
    count++;
    ml += beer.ml;
  }
  return WidgetSummary(dayKey: formatDayKey(today), count: count, ml: ml);
}

abstract interface class WidgetBridge {
  Future<void> push(WidgetSummary summary);
}

class NoopWidgetBridge implements WidgetBridge {
  const NoopWidgetBridge();

  @override
  Future<void> push(WidgetSummary summary) async {}
}

/// Every value is stored as a String so Dart and Kotlin cannot disagree about
/// integer width across the plugin's method channel.
class HomeWidgetBridge implements WidgetBridge {
  const HomeWidgetBridge();

  @override
  Future<void> push(WidgetSummary summary) async {
    await HomeWidget.saveWidgetData<String>(kPrefTodayKey, summary.dayKey);
    await HomeWidget.saveWidgetData<String>(
      kPrefTodayCount,
      '${summary.count}',
    );
    await HomeWidget.saveWidgetData<String>(kPrefTodayMl, '${summary.ml}');
    await HomeWidget.updateWidget(
      name: kAndroidWidgetName,
      androidName: kAndroidWidgetName,
    );
  }
}
