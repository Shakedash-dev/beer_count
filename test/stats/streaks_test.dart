import 'package:beer_count/stats/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

Set<DateTime> days(List<int> septemberDays) =>
    septemberDays.map((d) => DateTime(2026, 9, d)).toSet();

void main() {
  final today = DateTime(2026, 9, 20);

  test('empty history has no streaks', () {
    final r = computeStreaks(const <DateTime>{}, today);
    expect(r.currentDry, 0);
    expect(r.longestDry, 0);
    expect(r.currentDrinking, 0);
  });

  test('drinking today means a zero dry streak', () {
    final r = computeStreaks(days([18, 19, 20]), today);
    expect(r.currentDry, 0);
    expect(r.currentDrinking, 3);
  });

  test('current dry streak counts back from today', () {
    final r = computeStreaks(days([17]), today);
    expect(r.currentDry, 3, reason: '18, 19 and 20 are dry');
    expect(r.currentDrinking, 0);
  });

  test('longest dry streak includes the trailing gap up to today', () {
    expect(computeStreaks(days([1, 10]), today).longestDry, 10);
  });

  test('longest dry streak finds an interior gap', () {
    final r = computeStreaks(days([1, 15, 16, 17, 18, 19, 20]), today);
    expect(r.longestDry, 13, reason: '2..14 inclusive');
    expect(r.currentDry, 0);
  });

  test('days before the first entry are not counted as dry', () {
    expect(computeStreaks(days([20]), today).longestDry, 0);
  });

  test('a single entry today gives a drinking streak of one', () {
    final r = computeStreaks(days([20]), today);
    expect(r.currentDrinking, 1);
    expect(r.currentDry, 0);
  });

  test('future-dated days do not break the current streak logic', () {
    final r = computeStreaks(days([19, 20, 25]), today);
    expect(r.currentDrinking, 2);
    expect(r.currentDry, 0);
  });

  test('normalises a non-midnight today', () {
    final r = computeStreaks(days([20]), DateTime(2026, 9, 20, 23, 45));
    expect(r.currentDrinking, 1);
  });

  test('only future days means no history to measure', () {
    final r = computeStreaks(days([25]), today);
    expect(r.currentDry, 0);
    expect(r.currentDrinking, 0);
    expect(r.longestDry, 0);
  });
}
