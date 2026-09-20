import 'dart:io';

import 'package:beer_count/data/beer_log_file.dart';
import 'package:beer_count/models/beer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late BeerLogFile log;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('beerlog');
    log = BeerLogFile(File('${dir.path}/beer_log.ndjson'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Beer beerAt(int millis, int ml) => Beer(
        id: '$millis-aaaa',
        ml: ml,
        at: DateTime.fromMillisecondsSinceEpoch(millis),
      );

  test('missing file reads as an empty log', () async {
    final result = await log.readAll();
    expect(result.beers, isEmpty);
    expect(result.skippedLines, 0);
  });

  test('append then read round-trips in file order', () async {
    await log.append(beerAt(1000, 333));
    await log.append(beerAt(2000, 500));
    final result = await log.readAll();
    expect(result.beers.map((b) => b.ml), [333, 500]);
    expect(result.skippedLines, 0);
  });

  test('each append writes exactly one newline-terminated line', () async {
    await log.append(beerAt(1000, 333));
    await log.append(beerAt(2000, 500));
    final raw = await log.file.readAsString();
    expect(raw.endsWith('\n'), isTrue);
    expect(raw.split('\n').where((l) => l.isNotEmpty), hasLength(2));
  });

  test('skips malformed lines and counts them', () async {
    await log.file.writeAsString(
      '${beerAt(1000, 333).toJsonLine()}\n'
      'garbage\n'
      '\n'
      '{"id":"x"}\n'
      '${beerAt(2000, 500).toJsonLine()}\n',
    );
    final result = await log.readAll();
    expect(result.beers.map((b) => b.ml), [333, 500]);
    expect(result.skippedLines, 2, reason: 'blank lines are not failures');
  });

  test('recovers from a truncated final line and appends cleanly', () async {
    await log.file.writeAsString(
      '${beerAt(1000, 333).toJsonLine()}\n{"id":"trunc","ml":5',
    );
    await log.append(beerAt(3000, 500));
    final result = await log.readAll();
    expect(result.beers.map((b) => b.ml), [333, 500]);
    expect(result.skippedLines, 1);
  });

  test('rewrite replaces the whole file and leaves no temp behind', () async {
    await log.append(beerAt(1000, 333));
    await log.append(beerAt(2000, 500));
    await log.rewrite([beerAt(2000, 500)]);
    final result = await log.readAll();
    expect(result.beers.map((b) => b.id), ['2000-aaaa']);
    expect(
      Directory(dir.path).listSync().map((e) => e.path.split('/').last),
      ['beer_log.ndjson'],
      reason: 'temp file must not survive',
    );
  });

  test('clear empties the log', () async {
    await log.append(beerAt(1000, 333));
    await log.clear();
    expect((await log.readAll()).beers, isEmpty);
  });

  test('creates parent directories on append', () async {
    final nested = BeerLogFile(File('${dir.path}/a/b/beer_log.ndjson'));
    await nested.append(beerAt(1000, 333));
    expect((await nested.readAll()).beers, hasLength(1));
  });
}
