import '../models/beer.dart';

/// Count and volume for one local calendar day.
class DayCount {
  const DayCount({required this.day, required this.count, required this.ml});

  final DateTime day;
  final int count;
  final int ml;

  double get liters => ml / 1000;

  @override
  bool operator ==(Object other) =>
      other is DayCount &&
      other.day == day &&
      other.count == count &&
      other.ml == ml;

  @override
  int get hashCode => Object.hash(day, count, ml);

  @override
  String toString() => 'DayCount($day, $count, ${ml}ml)';
}

/// Local midnight of [t].
DateTime dayKey(DateTime t) => DateTime(t.year, t.month, t.day);

/// Calendar-day arithmetic. Never use `Duration(days: n)` for this: across a
/// DST transition a day is 23 or 25 hours and the result lands on the wrong
/// date. Israel observes DST, so this is not theoretical.
DateTime addDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

/// Signed number of calendar days from [from] to [to].
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Start of the week containing [t]. [weekStartWeekday] is one of
/// `DateTime.monday` (1) .. `DateTime.sunday` (7).
DateTime weekStartOf(DateTime t, int weekStartWeekday) {
  final delta = (t.weekday - weekStartWeekday) % 7;
  return addDays(dayKey(t), -delta);
}

Map<DateTime, List<Beer>> groupByDay(List<Beer> beers) {
  final grouped = <DateTime, List<Beer>>{};
  for (final beer in beers) {
    grouped.putIfAbsent(dayKey(beer.at), () => <Beer>[]).add(beer);
  }
  return grouped;
}

/// Inclusive, zero-filled, oldest first.
List<DayCount> dayCountsBetween(
  List<Beer> beers,
  DateTime from,
  DateTime to,
) {
  final start = dayKey(from);
  final end = dayKey(to);
  final span = daysBetween(start, end);
  if (span < 0) return const <DayCount>[];

  final counts = <DateTime, int>{};
  final volumes = <DateTime, int>{};
  for (final beer in beers) {
    final key = dayKey(beer.at);
    if (key.isBefore(start) || key.isAfter(end)) continue;
    counts[key] = (counts[key] ?? 0) + 1;
    volumes[key] = (volumes[key] ?? 0) + beer.ml;
  }

  return List<DayCount>.generate(span + 1, (i) {
    final day = addDays(start, i);
    return DayCount(day: day, count: counts[day] ?? 0, ml: volumes[day] ?? 0);
  });
}
