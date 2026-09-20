import 'dart:math';

import 'package:beer_count/models/beer.dart';
import 'package:beer_count/models/beer_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeerSize', () {
    test('has exactly two sizes with the spec volumes', () {
      expect(BeerSize.values, hasLength(2));
      expect(BeerSize.third.ml, 333);
      expect(BeerSize.half.ml, 500);
      expect(BeerSize.third.glyph, '⅓');
      expect(BeerSize.half.glyph, '½');
      expect(BeerSize.third.label, '1/3');
      expect(BeerSize.half.label, '1/2');
    });

    test('fromMl maps known volumes and nulls unknown ones', () {
      expect(BeerSize.fromMl(333), BeerSize.third);
      expect(BeerSize.fromMl(500), BeerSize.half);
      expect(BeerSize.fromMl(250), isNull);
    });
  });

  group('Beer', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1758391992123);

    test('create generates a stable id shape', () {
      final beer = Beer.create(ml: 333, at: at, random: Random(7));
      expect(beer.ml, 333);
      expect(beer.at, at);
      expect(
        RegExp(r'^\d+-[0-9a-f]{4}$').hasMatch(beer.id),
        isTrue,
        reason: 'got ${beer.id}',
      );
      expect(beer.id.split('-').first, '${at.millisecondsSinceEpoch}');
    });

    test('ids differ for the same instant', () {
      final random = Random(1);
      final ids = List.generate(
        50,
        (_) => Beer.create(ml: 500, at: at, random: random).id,
      ).toSet();
      expect(ids.length, greaterThan(1));
    });

    test('round-trips through a json line', () {
      final beer = Beer.create(ml: 500, at: at, random: Random(3));
      final decoded = Beer.fromJsonLine(beer.toJsonLine());
      expect(decoded.id, beer.id);
      expect(decoded.ml, beer.ml);
      expect(decoded.at, beer.at);
    });

    test('json line is single-line', () {
      final line = Beer.create(ml: 333, at: at, random: Random(3)).toJsonLine();
      expect(line, isNot(contains('\n')));
    });

    test('at is decoded as local time from epoch millis', () {
      const raw = '{"id":"1-aaaa","ml":333,"at":1758391992123}';
      final beer = Beer.fromJsonLine(raw);
      expect(beer.at.isUtc, isFalse);
      expect(beer.at.millisecondsSinceEpoch, 1758391992123);
    });

    test('tolerates unknown keys', () {
      const raw = '{"id":"1-aaaa","ml":500,"at":10,"brand":"Goldstar"}';
      expect(Beer.fromJsonLine(raw).ml, 500);
    });

    test('rejects malformed lines with FormatException', () {
      const bad = <String>[
        '',
        '   ',
        'not json',
        '{"id":"x"}',
        '{"ml":333,"at":10}',
        '{"id":"x","ml":"333","at":10}',
        '{"id":"x","ml":333,"at":"soon"}',
        '{"id":"","ml":333,"at":10}',
        '{"id":"x","ml":0,"at":10}',
        '[1,2,3]',
      ];
      for (final line in bad) {
        expect(
          () => Beer.fromJsonLine(line),
          throwsFormatException,
          reason: 'should reject: $line',
        );
      }
    });

    test('liters and size derive from ml', () {
      expect(Beer.create(ml: 500, at: at).liters, 0.5);
      expect(Beer.create(ml: 333, at: at).size, BeerSize.third);
      expect(Beer.create(ml: 250, at: at).size, isNull);
    });

    test('equality is by id', () {
      final a = Beer(id: 'x', ml: 333, at: at);
      expect(a, Beer(id: 'x', ml: 500, at: at.add(const Duration(hours: 1))));
      expect(a, isNot(Beer(id: 'y', ml: 333, at: at)));
    });
  });
}
