import 'package:home_widget/home_widget.dart';

import '../models/beer.dart';
import '../stats/buckets.dart';

/// Must match the Kotlin class name of the AppWidgetProvider.
const String kAndroidWidgetName = 'BeerWidgetProvider';

const String kPrefTodayKey = 'today_key';
const String kPrefTodayCount = 'today_count';
const String kPrefTodayMl = 'today_ml';
const String kPrefWeekKey = 'week_key';
const String kPrefWeekCount = 'week_count';
const String kPrefWeekGoal = 'week_goal';
const String kPrefWeekStart = 'week_start';

String formatDayKey(DateTime day) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

/// The tiny cache the home-screen widget renders from. The NDJSON log stays
/// the source of truth; this is recomputed from it on every app load, so a
/// divergence heals itself the next time the app is opened.
///
/// The week fields let the widget switch into its goal-reached look and keep
/// counting the week on its own between app launches. [weekStart] travels
/// with them because Kotlin needs it to notice the week rolling over.
class WidgetSummary {
  const WidgetSummary({
    required this.dayKey,
    required this.count,
    required this.ml,
    this.weekKey = '',
    this.weekCount = 0,
    this.weekGoal = 0,
    this.weekStart = DateTime.sunday,
  });

  static const empty = WidgetSummary(dayKey: '', count: 0, ml: 0);

  final String dayKey;
  final int count;
  final int ml;

  /// Day key of the first day of the current week.
  final String weekKey;
  final int weekCount;

  /// Zero means the goal is off and the widget never enters goal mode.
  final int weekGoal;

  /// `DateTime.monday` (1) .. `DateTime.sunday` (7), same as ISO in Kotlin.
  final int weekStart;

  bool get goalReached => weekGoal > 0 && weekCount >= weekGoal;

  @override
  bool operator ==(Object other) =>
      other is WidgetSummary &&
      other.dayKey == dayKey &&
      other.count == count &&
      other.ml == ml &&
      other.weekKey == weekKey &&
      other.weekCount == weekCount &&
      other.weekGoal == weekGoal &&
      other.weekStart == weekStart;

  @override
  int get hashCode => Object.hash(
        dayKey,
        count,
        ml,
        weekKey,
        weekCount,
        weekGoal,
        weekStart,
      );

  @override
  String toString() => 'WidgetSummary($dayKey, $count, ${ml}ml, '
      'week $weekKey $weekCount/$weekGoal)';
}

WidgetSummary summarizeToday(
  List<Beer> beers,
  DateTime now, {
  int weeklyGoal = 0,
  int weekStartWeekday = DateTime.sunday,
}) {
  final today = dayKey(now);
  final weekStart = weekStartOf(now, weekStartWeekday);
  final nextWeek = addDays(weekStart, 7);
  var count = 0;
  var ml = 0;
  var weekCount = 0;
  for (final beer in beers) {
    final day = dayKey(beer.at);
    if (!day.isBefore(weekStart) && day.isBefore(nextWeek)) weekCount++;
    if (day != today) continue;
    count++;
    ml += beer.ml;
  }
  return WidgetSummary(
    dayKey: formatDayKey(today),
    count: count,
    ml: ml,
    weekKey: formatDayKey(weekStart),
    weekCount: weekCount,
    weekGoal: weeklyGoal,
    weekStart: weekStartWeekday,
  );
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
    await HomeWidget.saveWidgetData<String>(kPrefWeekKey, summary.weekKey);
    await HomeWidget.saveWidgetData<String>(
      kPrefWeekCount,
      '${summary.weekCount}',
    );
    await HomeWidget.saveWidgetData<String>(
      kPrefWeekGoal,
      '${summary.weekGoal}',
    );
    await HomeWidget.saveWidgetData<String>(
      kPrefWeekStart,
      '${summary.weekStart}',
    );
    await HomeWidget.updateWidget(
      name: kAndroidWidgetName,
      androidName: kAndroidWidgetName,
    );
  }
}
