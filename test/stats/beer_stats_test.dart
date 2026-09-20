import 'package:beer_count/models/beer.dart';
import 'package:beer_count/stats/beer_stats.dart';
import 'package:beer_count/stats/buckets.dart';
import 'package:flutter_test/flutter_test.dart';

var _seq = 0;
Beer at(DateTime t, [int ml = 333]) =>
    Beer(id: '${t.millisecondsSinceEpoch}-${_seq++}', ml: ml, at: t);

// 2026-09-20 is a Sunday.
final now = DateTime(2026, 9, 20, 21, 30);

BeerStats build(
  List<Beer> beers, {
  int goal = 14,
  int weekStart = DateTime.sunday,
}) =>
    BeerStats.from(
      beers,
      now: now,
      weekStartWeekday: weekStart,
      weeklyGoal: goal,
    );

void main() {
  group('empty log', () {
    final stats = build(const []);

    test('is empty and every aggregate is a safe zero', () {
      expect(stats.isEmpty, isTrue);
      expect(stats.totalCount, 0);
      expect(stats.todayCount, 0);
      expect(stats.weekCount, 0);
      expect(stats.daysTracked, 0);
      expect(stats.firstEntry, isNull);
      expect(stats.dailyAvg30, 0);
      expect(stats.weeklyAvg12, 0);
      expect(stats.peakHour, isNull);
      expect(stats.biggestDay, isNull);
      expect(stats.goalFraction, 0);
      expect(stats.overGoal, isFalse);
      expect(stats.currentDryStreak, 0);
      expect(stats.weeksConsidered, 0);
    });

    test('still returns correctly shaped series', () {
      expect(stats.avgByWeekday, hasLength(7));
      expect(stats.countByHour, hasLength(24));
      expect(stats.last30Days, hasLength(30));
      expect(stats.yearGrid, hasLength(371));
      expect(stats.last30Days.every((d) => d.count == 0), isTrue);
    });
  });

  group('single entry today', () {
    final stats = build([at(DateTime(2026, 9, 20, 20), 500)]);

    test('counts today and all time', () {
      expect(stats.isEmpty, isFalse);
      expect(stats.todayCount, 1);
      expect(stats.todayMl, 500);
      expect(stats.todayLiters, 0.5);
      expect(stats.totalCount, 1);
      expect(stats.totalMl, 500);
      expect(stats.daysTracked, 1);
      expect(stats.activeDays, 1);
      expect(stats.firstEntry, DateTime(2026, 9, 20, 20));
    });

    test('week bucket uses the configured week start', () {
      expect(stats.weekCount, 1);
      expect(
        build([at(DateTime(2026, 9, 20, 20))], weekStart: DateTime.monday)
            .weekCount,
        1,
      );
    });

    test('peak hour and size split', () {
      expect(stats.peakHour, 20);
      expect(stats.countByHour[20], 1);
      expect(stats.halfCount, 1);
      expect(stats.thirdCount, 0);
      expect(stats.otherCount, 0);
    });

    test('biggest day is that day', () {
      expect(stats.biggestDay, isNotNull);
      expect(stats.biggestDay!.day, DateTime(2026, 9, 20));
      expect(stats.biggestDay!.count, 1);
    });
  });

  group('week comparison', () {
    // Sunday start: this week begins 2026-09-20, last week is 09-13..09-19.
    final stats = build([
      at(DateTime(2026, 9, 20, 18)),
      at(DateTime(2026, 9, 20, 19)),
      at(DateTime(2026, 9, 15, 18)),
      at(DateTime(2026, 9, 16, 18)),
      at(DateTime(2026, 9, 17, 18)),
    ]);

    test('splits this week from last week', () {
      expect(stats.weekCount, 2);
      expect(stats.lastWeekCount, 3);
      expect(stats.weekDelta, -1);
    });

    test('goal fraction tracks the weekly goal', () {
      expect(stats.weeklyGoal, 14);
      expect(stats.goalFraction, closeTo(2 / 14, 1e-9));
      expect(stats.overGoal, isFalse);
    });

    test('a zero goal disables the goal entirely', () {
      final noGoal = build([at(DateTime(2026, 9, 20, 18))], goal: 0);
      expect(noGoal.goalFraction, 0);
      expect(noGoal.overGoal, isFalse);
      expect(noGoal.weeksConsidered, 0);
      expect(noGoal.weeksUnderGoal, 0);
    });

    test('over goal flips when the week exceeds it', () {
      final many = List.generate(5, (i) => at(DateTime(2026, 9, 20, 12 + i)));
      expect(build(many, goal: 4).overGoal, isTrue);
    });
  });

  group('averages', () {
    test('dailyAvg30 divides by 30 calendar days', () {
      final beers = [
        for (var i = 0; i < 15; i++)
          at(addDays(DateTime(2026, 9, 20), -i).add(const Duration(hours: 18))),
      ];
      expect(build(beers).dailyAvg30, closeTo(15 / 30, 1e-9));
    });

    test('dailyAvg30 ignores entries older than 30 days', () {
      final beers = [
        at(DateTime(2026, 9, 20, 18)),
        at(addDays(DateTime(2026, 9, 20), -45).add(const Duration(hours: 18))),
      ];
      expect(build(beers).dailyAvg30, closeTo(1 / 30, 1e-9));
    });

    test('avgByWeekday averages over weekday occurrences', () {
      final beers = <Beer>[];
      for (var w = 0; w < 4; w++) {
        final day = addDays(DateTime(2026, 9, 20), -7 * w);
        beers
          ..add(at(DateTime(day.year, day.month, day.day, 18)))
          ..add(at(DateTime(day.year, day.month, day.day, 20)));
      }
      final stats = build(beers);
      expect(stats.avgByWeekday, hasLength(7));
      expect(stats.avgByWeekday[DateTime.sunday - 1], closeTo(2, 1e-9));
      expect(stats.avgByWeekday[DateTime.wednesday - 1], 0);
    });

    test('weeklyAvg12 averages the tracked weeks', () {
      // Two beers this week, two last week, nothing before.
      final stats = build([
        at(DateTime(2026, 9, 20, 18)),
        at(DateTime(2026, 9, 20, 19)),
        at(DateTime(2026, 9, 15, 18)),
        at(DateTime(2026, 9, 16, 18)),
      ]);
      expect(stats.weeklyAvg12, closeTo(2, 1e-9));
    });
  });

  group('series', () {
    test('last30Days ends today and is zero-filled', () {
      final stats = build([at(DateTime(2026, 9, 20, 18))]);
      expect(stats.last30Days, hasLength(30));
      expect(stats.last30Days.last.day, DateTime(2026, 9, 20));
      expect(stats.last30Days.last.count, 1);
      expect(stats.last30Days.first.day, addDays(DateTime(2026, 9, 20), -29));
      expect(stats.last30Days.first.count, 0);
    });

    test('yearGrid is week-aligned and 371 days long', () {
      final stats = build([at(DateTime(2026, 9, 20, 18))]);
      expect(stats.yearGrid, hasLength(371));
      expect(stats.yearGrid.first.day.weekday, DateTime.sunday);
      expect(stats.yearGrid.last.day, addDays(stats.yearGrid.first.day, 370));
      expect(
        stats.yearGrid
            .firstWhere((d) => d.day == DateTime(2026, 9, 20))
            .count,
        1,
      );
    });

    test('yearGrid respects a Monday week start', () {
      final stats = build(
        [at(DateTime(2026, 9, 20, 18))],
        weekStart: DateTime.monday,
      );
      expect(stats.yearGrid.first.day.weekday, DateTime.monday);
    });
  });

  group('streaks and records', () {
    test('surfaces streaks from the streak module', () {
      final stats = build([
        at(DateTime(2026, 9, 18, 18)),
        at(DateTime(2026, 9, 19, 18)),
        at(DateTime(2026, 9, 20, 18)),
      ]);
      expect(stats.currentDrinkingStreak, 3);
      expect(stats.currentDryStreak, 0);
    });

    test('dry streak counts back from today', () {
      expect(build([at(DateTime(2026, 9, 16, 18))]).currentDryStreak, 4);
    });

    test('biggest day picks the highest count, earliest on a tie', () {
      final stats = build([
        at(DateTime(2026, 9, 10, 18)),
        at(DateTime(2026, 9, 10, 19)),
        at(DateTime(2026, 9, 12, 18)),
        at(DateTime(2026, 9, 12, 19)),
      ]);
      expect(stats.biggestDay!.day, DateTime(2026, 9, 10));
      expect(stats.biggestDay!.count, 2);
    });

    test('weeks under goal only counts completed weeks', () {
      final beers = <Beer>[
        at(DateTime(2026, 9, 15, 18)),
        at(DateTime(2026, 9, 16, 18)),
        at(DateTime(2026, 9, 17, 18)),
        for (var i = 0; i < 99; i++) at(DateTime(2026, 9, 20, 10)),
      ];
      final stats = build(beers, goal: 5);
      expect(stats.weeksConsidered, 1);
      expect(stats.weeksUnderGoal, 1);
    });

    test('a completed week over goal is not counted as under', () {
      final beers = <Beer>[
        for (var i = 0; i < 9; i++) at(DateTime(2026, 9, 15, 10 + i)),
      ];
      final stats = build(beers, goal: 5);
      expect(stats.weeksConsidered, 1);
      expect(stats.weeksUnderGoal, 0);
    });
  });

  group('boundaries', () {
    test('an entry just after midnight belongs to the new day', () {
      expect(build([at(DateTime(2026, 9, 20, 0, 1))]).todayCount, 1);
    });

    test('an entry just before midnight belongs to the old day', () {
      final stats = build([at(DateTime(2026, 9, 19, 23, 59))]);
      expect(stats.todayCount, 0);
      expect(stats.totalCount, 1);
    });

    test('unknown volumes land in otherCount', () {
      final stats = build([at(DateTime(2026, 9, 20, 18), 250)]);
      expect(stats.otherCount, 1);
      expect(stats.thirdCount, 0);
      expect(stats.halfCount, 0);
      expect(stats.totalMl, 250);
    });

    test('input order does not matter', () {
      final ordered = build([
        at(DateTime(2026, 9, 18, 18)),
        at(DateTime(2026, 9, 20, 18)),
      ]);
      final reversed = build([
        at(DateTime(2026, 9, 20, 18)),
        at(DateTime(2026, 9, 18, 18)),
      ]);
      expect(reversed.firstEntry, ordered.firstEntry);
      expect(reversed.daysTracked, ordered.daysTracked);
      expect(reversed.totalCount, ordered.totalCount);
      expect(reversed.dailyAvg30, ordered.dailyAvg30);
    });

    test('an entry dated in the future does not break anything', () {
      final stats = build([at(DateTime(2026, 12, 25, 18))]);
      expect(stats.totalCount, 1);
      expect(stats.todayCount, 0);
      expect(stats.daysTracked, greaterThanOrEqualTo(0));
    });
  });
}
