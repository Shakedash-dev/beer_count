import 'package:beer_count/data/exporter.dart';
import 'package:beer_count/data/importer.dart';
import 'package:beer_count/models/beer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final beers = [
    Beer(id: '1-aaaa', ml: 333, at: DateTime(2026, 9, 19, 23, 10)),
    Beer(id: '2-bbbb', ml: 500, at: DateTime(2026, 9, 20, 18)),
  ];

  test('reads back exactly what the JSON export writes', () {
    final result = beersFromJson(beersToJson(beers));
    expect(result.skipped, 0);
    expect(result.beers.map((b) => (b.id, b.ml, b.at)), [
      ('1-aaaa', 333, DateTime(2026, 9, 19, 23, 10)),
      ('2-bbbb', 500, DateTime(2026, 9, 20, 18)),
    ]);
  });

  test('skips and counts bad records instead of failing the file', () {
    const source = '[{"id":"ok","ml":333,"at":1},'
        '{"id":"","ml":333,"at":1},{"id":"x","ml":0,"at":1},42]';
    final result = beersFromJson(source);
    expect(result.beers.single.id, 'ok');
    expect(result.skipped, 3);
  });

  test('rejects text that is not a json array', () {
    expect(() => beersFromJson('{"id":"x"}'), throwsFormatException);
    expect(() => beersFromJson('id,ml\n1,333'), throwsFormatException);
  });
}
