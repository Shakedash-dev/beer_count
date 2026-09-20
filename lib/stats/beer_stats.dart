import '../models/beer.dart';
import '../models/beer_size.dart';
import 'buckets.dart';
import 'streaks.dart';

/// Every number the UI shows, computed once from the whole log.
///
/// Pure: no IO, no ambient clock. [now] is injected so the whole thing is
/// deterministically testable.
class BeerStats {
  const BeerStats._({
    required this.todayCount,
    required this.todayMl,
    required this.weekCount,
    required this.weekMl,
    required this.lastWeekCount,
    required this.weeklyGoal,
    required this.totalCount,
    required this.totalMl,
    required this.daysTracked,
    required this.activeDays,
    required this.firstEntry,
    required this.dailyAvg30,
    required this.weeklyAvg12,
    required this.avgByWeekday,
    required this.countByHour,
    required this.peakHour,
    required this.last30Days,
    required this.currentDryStreak,
    required this.longestDryStreak,
    required this.currentDrinkingStreak,
    required this.biggestDay,
    required this.weeksUnderGoal,
    required this.weeksConsidered,
    required this.thirdCount,
    required this.halfCount,
    required this.otherCount,
    required this.yearGrid,
  });

  factory BeerStats.from(
    List<Beer> beers, {
    required DateTime now,
    required int weekStartWeekday,
    required int weeklyGoal,
  }) {
    final today = dayKey(now);
    final weekStart = weekStartOf(now, weekStartWeekday);
    final nextWeekStart = addDays(weekStart, 7);
    final lastWeekStart = addDays(weekStart, -7);

    final gridEnd = addDays(weekStart, 6);
    final gridStart = addDays(gridEnd, -370);
    final yearGrid = dayCountsBetween(beers, gridStart, gridEnd);
    final last30Days = dayCountsBetween(beers, addDays(today, -29), today);

    if (beers.isEmpty) {
      return BeerStats._(
        todayCount: 0,
        todayMl: 0,
        weekCount: 0,
        weekMl: 0,
        lastWeekCount: 0,
        weeklyGoal: weeklyGoal,
        totalCount: 0,
        totalMl: 0,
        daysTracked: 0,
        activeDays: 0,
        firstEntry: null,
        dailyAvg30: 0,
        weeklyAvg12: 0,
        avgByWeekday: List<double>.filled(7, 0),
        countByHour: List<int>.filled(24, 0),
        peakHour: null,
        last30Days: last30Days,
        currentDryStreak: 0,
        longestDryStreak: 0,
        currentDrinkingStreak: 0,
        biggestDay: null,
        weeksUnderGoal: 0,
        weeksConsidered: 0,
        thirdCount: 0,
        halfCount: 0,
        otherCount: 0,
        yearGrid: yearGrid,
      );
    }

    var todayCount = 0;
    var todayMl = 0;
    var weekCount = 0;
    var weekMl = 0;
    var lastWeekCount = 0;
    var totalMl = 0;
    var thirdCount = 0;
    var halfCount = 0;
    var otherCount = 0;
    final countByHour = List<int>.filled(24, 0);
    final byWeekdayTotal = List<int>.filled(7, 0);
    var firstEntry = beers.first.at;

    for (final beer in beers) {
      if (beer.at.isBefore(firstEntry)) firstEntry = beer.at;
      final day = dayKey(beer.at);
      totalMl += beer.ml;
      countByHour[beer.at.hour]++;
      byWeekdayTotal[beer.at.weekday - 1]++;

      switch (beer.size) {
        case BeerSize.third:
          thirdCount++;
        case BeerSize.half:
          halfCount++;
        case null:
          otherCount++;
      }

      if (day == today) {
        todayCount++;
        todayMl += beer.ml;
      }
      if (!day.isBefore(weekStart) && day.isBefore(nextWeekStart)) {
        weekCount++;
        weekMl += beer.ml;
      } else if (!day.isBefore(lastWeekStart) && day.isBefore(weekStart)) {
        lastWeekCount++;
      }
    }

    final firstDay = dayKey(firstEntry);
    final trackedSpan = daysBetween(firstDay, today);
    // A future-dated entry would make this negative; the log still has one
    // day of history as far as the UI is concerned.
    final daysTracked = trackedSpan < 0 ? 1 : trackedSpan + 1;

    final dayCounts = dayCountsBetween(beers, firstDay, today);
    final activeDays = dayCounts.where((d) => d.count > 0).length;

    DayCount? biggestDay;
    for (final d in dayCounts) {
      if (d.count == 0) continue;
      if (biggestDay == null || d.count > biggestDay.count) biggestDay = d;
    }

    final last30Count = last30Days.fold<int>(0, (sum, d) => sum + d.count);

    final weekdayOccurrences = List<int>.filled(7, 0);
    for (final d in dayCounts) {
      weekdayOccurrences[d.day.weekday - 1]++;
    }
    final avgByWeekday = List<double>.generate(7, (i) {
      final occurrences = weekdayOccurrences[i];
      return occurrences == 0 ? 0 : byWeekdayTotal[i] / occurrences;
    });

    var peakHour = 0;
    for (var h = 1; h < 24; h++) {
      if (countByHour[h] > countByHour[peakHour]) peakHour = h;
    }

    // Week buckets: index 0 is the current week, 1 is last week, and so on.
    final weekTotals = List<int>.filled(13, 0);
    for (final beer in beers) {
      final bucketStart = weekStartOf(beer.at, weekStartWeekday);
      final index = daysBetween(bucketStart, weekStart) ~/ 7;
      if (index >= 0 && index < weekTotals.length) weekTotals[index]++;
    }

    final trackedWeeks =
        (daysBetween(weekStartOf(firstDay, weekStartWeekday), weekStart) ~/ 7) +
            1;
    final weeksForAvg = trackedWeeks.clamp(1, 12);
    final weeklyAvg12 =
        weekTotals.take(weeksForAvg).fold<int>(0, (sum, c) => sum + c) /
            weeksForAvg;

    var weeksConsidered = 0;
    var weeksUnderGoal = 0;
    if (weeklyGoal > 0) {
      final completed = (trackedWeeks - 1).clamp(0, 12);
      for (var i = 1; i <= completed; i++) {
        weeksConsidered++;
        if (weekTotals[i] <= weeklyGoal) weeksUnderGoal++;
      }
    }

    final streaks = computeStreaks(
      dayCounts.where((d) => d.count > 0).map((d) => d.day).toSet(),
      today,
    );

    return BeerStats._(
      todayCount: todayCount,
      todayMl: todayMl,
      weekCount: weekCount,
      weekMl: weekMl,
      lastWeekCount: lastWeekCount,
      weeklyGoal: weeklyGoal,
      totalCount: beers.length,
      totalMl: totalMl,
      daysTracked: daysTracked,
      activeDays: activeDays,
      firstEntry: firstEntry,
      dailyAvg30: last30Count / 30,
      weeklyAvg12: weeklyAvg12,
      avgByWeekday: avgByWeekday,
      countByHour: countByHour,
      peakHour: countByHour[peakHour] == 0 ? null : peakHour,
      last30Days: last30Days,
      currentDryStreak: streaks.currentDry,
      longestDryStreak: streaks.longestDry,
      currentDrinkingStreak: streaks.currentDrinking,
      biggestDay: biggestDay,
      weeksUnderGoal: weeksUnderGoal,
      weeksConsidered: weeksConsidered,
      thirdCount: thirdCount,
      halfCount: halfCount,
      otherCount: otherCount,
      yearGrid: yearGrid,
    );
  }

  final int todayCount;
  final int todayMl;
  final int weekCount;
  final int weekMl;
  final int lastWeekCount;
  final int weeklyGoal;
  final int totalCount;
  final int totalMl;
  final int daysTracked;
  final int activeDays;
  final DateTime? firstEntry;
  final double dailyAvg30;
  final double weeklyAvg12;

  /// Length 7, indexed by `DateTime.weekday - 1` (Monday first).
  final List<double> avgByWeekday;

  /// Length 24, indexed by local hour.
  final List<int> countByHour;
  final int? peakHour;

  /// Length 30, oldest first, ending today.
  final List<DayCount> last30Days;
  final int currentDryStreak;
  final int longestDryStreak;
  final int currentDrinkingStreak;
  final DayCount? biggestDay;
  final int weeksUnderGoal;
  final int weeksConsidered;
  final int thirdCount;
  final int halfCount;
  final int otherCount;

  /// Length 371 (53 weeks), oldest first, aligned to the configured week
  /// start and ending on the last day of the current week.
  final List<DayCount> yearGrid;

  bool get isEmpty => totalCount == 0;

  double get todayLiters => todayMl / 1000;
  double get weekLiters => weekMl / 1000;
  double get totalLiters => totalMl / 1000;

  int get weekDelta => weekCount - lastWeekCount;

  double get goalFraction => weeklyGoal <= 0 ? 0 : weekCount / weeklyGoal;

  bool get overGoal => weeklyGoal > 0 && weekCount > weeklyGoal;

  int get thirdPercent =>
      totalCount == 0 ? 0 : (thirdCount / totalCount * 100).round();

  int get halfPercent =>
      totalCount == 0 ? 0 : (halfCount / totalCount * 100).round();
}
