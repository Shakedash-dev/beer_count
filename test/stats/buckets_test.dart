import 'package:beer_count/models/beer.dart';
import 'package:beer_count/stats/buckets.dart';
import 'package:flutter_test/flutter_test.dart';

Beer at(DateTime t, [int ml = 333]) =>
    Beer(id: '${t.millisecondsSinceEpoch}-aaaa', ml: ml, at: t);

void main() {
  test('dayKey strips the time component', () {
    expect(dayKey(DateTime(2026, 3, 27, 23, 59, 59)), DateTime(2026, 3, 27));
    expect(dayKey(DateTime(2026, 3, 27)), DateTime(2026, 3, 27));
  });

  test('addDays uses calendar arithmetic, not Duration', () {
    expect(addDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
    expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
  });

  test('addDays never drifts off local midnight, DST or not', () {
    for (var month = 1; month <= 12; month++) {
      for (final day in [1, 15, 27, 28]) {
        final start = DateTime(2026, month, day);
        final next = addDays(start, 1);
        expect(next.hour, 0, reason: 'drifted at $start');
        expect(daysBetween(start, next), 1);
      }
    }
  });

  test('daysBetween is signed', () {
    expect(daysBetween(DateTime(2026, 1, 1), DateTime(2026, 1, 1)), 0);
    expect(daysBetween(DateTime(2026, 1, 1), DateTime(2026, 1, 8)), 7);
    expect(daysBetween(DateTime(2026, 1, 8), DateTime(2026, 1, 1)), -7);
    expect(daysBetween(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 1);
  });

  test('weekStartOf honours a Sunday week start', () {
    expect(
      weekStartOf(DateTime(2026, 9, 20, 13), DateTime.sunday),
      DateTime(2026, 9, 20),
    );
    expect(
      weekStartOf(DateTime(2026, 9, 26), DateTime.sunday),
      DateTime(2026, 9, 20),
    );
  });

  test('weekStartOf honours a Monday week start', () {
    expect(
      weekStartOf(DateTime(2026, 9, 20), DateTime.monday),
      DateTime(2026, 9, 14),
    );
    expect(
      weekStartOf(DateTime(2026, 9, 21), DateTime.monday),
      DateTime(2026, 9, 21),
    );
  });

  test('groupByDay buckets by local day and keeps entries', () {
    final grouped = groupByDay([
      at(DateTime(2026, 9, 20, 23, 30)),
      at(DateTime(2026, 9, 21, 0, 15)),
      at(DateTime(2026, 9, 21, 22)),
    ]);
    expect(grouped.keys.toSet(), {DateTime(2026, 9, 20), DateTime(2026, 9, 21)});
    expect(grouped[DateTime(2026, 9, 21)], hasLength(2));
  });

  test('dayCountsBetween zero-fills gaps and sums ml', () {
    final counts = dayCountsBetween(
      [
        at(DateTime(2026, 9, 18, 20), 333),
        at(DateTime(2026, 9, 20, 20), 500),
        at(DateTime(2026, 9, 20, 22), 500),
      ],
      DateTime(2026, 9, 18),
      DateTime(2026, 9, 21),
    );
    expect(counts.map((d) => d.day), [
      DateTime(2026, 9, 18),
      DateTime(2026, 9, 19),
      DateTime(2026, 9, 20),
      DateTime(2026, 9, 21),
    ]);
    expect(counts.map((d) => d.count), [1, 0, 2, 0]);
    expect(counts.map((d) => d.ml), [333, 0, 1000, 0]);
  });

  test('dayCountsBetween ignores beers outside the range', () {
    final counts = dayCountsBetween(
      [at(DateTime(2026, 1, 1)), at(DateTime(2026, 9, 20))],
      DateTime(2026, 9, 20),
      DateTime(2026, 9, 20),
    );
    expect(counts, hasLength(1));
    expect(counts.single.count, 1);
  });

  test('dayCountsBetween returns empty when the range is inverted', () {
    expect(
      dayCountsBetween(const [], DateTime(2026, 9, 21), DateTime(2026, 9, 20)),
      isEmpty,
    );
  });

  test('DayCount has value equality and liters', () {
    final day = DateTime(2026, 9, 20);
    const two = 2;
    expect(
      DayCount(day: day, count: two, ml: 1000),
      DayCount(day: day, count: two, ml: 1000),
    );
    expect(DayCount(day: day, count: two, ml: 1000).liters, 1.0);
    expect(
      DayCount(day: day, count: two, ml: 1000),
      isNot(DayCount(day: day, count: 3, ml: 1000)),
    );
  });
}
