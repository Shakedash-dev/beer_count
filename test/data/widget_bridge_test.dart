import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/models/beer.dart';
import 'package:flutter_test/flutter_test.dart';

Beer at(DateTime t, int ml) =>
    Beer(id: '${t.millisecondsSinceEpoch}-aaaa', ml: ml, at: t);

void main() {
  final now = DateTime(2026, 9, 20, 21, 30);

  test('formatDayKey zero-pads', () {
    expect(formatDayKey(DateTime(2026, 9, 7)), '2026-09-07');
    expect(formatDayKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('summarizes only today', () {
    final summary = summarizeToday([
      at(DateTime(2026, 9, 20, 18), 333),
      at(DateTime(2026, 9, 20, 20), 500),
      at(DateTime(2026, 9, 19, 20), 500),
    ], now);
    expect(summary.dayKey, '2026-09-20');
    expect(summary.count, 2);
    expect(summary.ml, 833);
  });

  test('an empty day still carries today key', () {
    final summary = summarizeToday(const [], now);
    expect(summary.dayKey, '2026-09-20');
    expect(summary.count, 0);
    expect(summary.ml, 0);
  });

  test('value equality', () {
    expect(
      summarizeToday(const [], now),
      summarizeToday(const [], DateTime(2026, 9, 20, 1)),
    );
    expect(
      summarizeToday(const [], now),
      isNot(summarizeToday(const [], DateTime(2026, 9, 21, 1))),
    );
  });

  test('the widget provider name matches the kotlin class', () {
    expect(kAndroidWidgetName, 'BeerWidgetProvider');
  });

  test('noop bridge does nothing and does not throw', () async {
    await const NoopWidgetBridge().push(WidgetSummary.empty);
  });
}
