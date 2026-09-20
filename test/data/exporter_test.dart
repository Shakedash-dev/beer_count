import 'dart:convert';

import 'package:beer_count/data/exporter.dart';
import 'package:beer_count/models/beer.dart';
import 'package:flutter_test/flutter_test.dart';

Beer at(DateTime t, int ml) =>
    Beer(id: '${t.millisecondsSinceEpoch}-aaaa', ml: ml, at: t);

void main() {
  final beers = [
    at(DateTime(2026, 9, 20, 21, 5), 500),
    at(DateTime(2026, 9, 18, 9, 30), 333),
  ];

  test('csv has a header and one row per beer, oldest first', () {
    final lines = const LineSplitter().convert(beersToCsv(beers));
    expect(lines.first, 'id,logged_at_local,epoch_ms,ml,size');
    expect(lines, hasLength(3));
    expect(lines[1], contains('2026-09-18T09:30:00'));
    expect(lines[1], endsWith(',333,1/3'));
    expect(lines[2], endsWith(',500,1/2'));
  });

  test('csv labels an unknown volume as "other"', () {
    expect(beersToCsv([at(DateTime(2026, 9, 20, 12), 250)]), contains(',250,other'));
  });

  test('csv of an empty log is just the header', () {
    expect(beersToCsv(const []).trim(), 'id,logged_at_local,epoch_ms,ml,size');
  });

  test('json is a parseable list, oldest first', () {
    final decoded = jsonDecode(beersToJson(beers)) as List<Object?>;
    expect(decoded, hasLength(2));
    final first = decoded.first! as Map<String, Object?>;
    expect(first['ml'], 333);
    expect(first['at'], DateTime(2026, 9, 18, 9, 30).millisecondsSinceEpoch);
  });

  test('json round-trips back into Beer objects', () {
    final decoded = jsonDecode(beersToJson(beers)) as List<Object?>;
    final back = decoded.map((e) => Beer.fromJsonLine(jsonEncode(e))).toList();
    expect(back.map((b) => b.ml), [333, 500]);
  });

  test('json of an empty log is an empty array', () {
    expect(jsonDecode(beersToJson(const [])), isEmpty);
  });
}
