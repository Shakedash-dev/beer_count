import 'buckets.dart';

class StreakResult {
  const StreakResult({
    required this.currentDry,
    required this.longestDry,
    required this.currentDrinking,
  });

  static const none =
      StreakResult(currentDry: 0, longestDry: 0, currentDrinking: 0);

  /// Consecutive days ending today with no beers. Zero if today has one.
  final int currentDry;

  /// Longest run of dry days since the first ever entry, including the run
  /// that ends today. Days before the first entry do not count.
  final int longestDry;

  /// Consecutive days ending today with at least one beer. Zero if today has
  /// none.
  final int currentDrinking;
}

/// [activeDays] must contain day keys (local midnights).
StreakResult computeStreaks(Set<DateTime> activeDays, DateTime today) {
  if (activeDays.isEmpty) return StreakResult.none;

  final end = dayKey(today);
  final active = activeDays.where((d) => !d.isAfter(end)).toSet();
  if (active.isEmpty) return StreakResult.none;

  final first = active.reduce((a, b) => a.isBefore(b) ? a : b);

  var currentDry = 0;
  var cursor = end;
  while (!active.contains(cursor) && !cursor.isBefore(first)) {
    currentDry++;
    cursor = addDays(cursor, -1);
  }

  var currentDrinking = 0;
  cursor = end;
  while (active.contains(cursor)) {
    currentDrinking++;
    cursor = addDays(cursor, -1);
  }

  var longestDry = 0;
  var run = 0;
  final span = daysBetween(first, end);
  for (var i = 0; i <= span; i++) {
    if (active.contains(addDays(first, i))) {
      run = 0;
    } else {
      run++;
      if (run > longestDry) longestDry = run;
    }
  }

  return StreakResult(
    currentDry: currentDry,
    longestDry: longestDry,
    currentDrinking: currentDrinking,
  );
}
