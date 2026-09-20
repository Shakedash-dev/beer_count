import 'dart:io';

import 'package:beer_count/data/beer_log_file.dart';
import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/models/beer.dart';
import 'package:beer_count/models/beer_size.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBridge implements WidgetBridge {
  final pushes = <WidgetSummary>[];

  @override
  Future<void> push(WidgetSummary summary) async => pushes.add(summary);
}

void main() {
  late Directory dir;
  late BeerLogFile log;
  late FakeBridge bridge;
  late BeerRepository repo;
  var now = DateTime(2026, 9, 20, 21, 30);

  setUp(() {
    now = DateTime(2026, 9, 20, 21, 30);
    dir = Directory.systemTemp.createTempSync('beerrepo');
    log = BeerLogFile(File('${dir.path}/beer_log.ndjson'));
    bridge = FakeBridge();
    repo = BeerRepository(log: log, widget: bridge, clock: () => now);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('loads an empty log without error', () async {
    await repo.load();
    expect(repo.beers, isEmpty);
    expect(repo.isLoading, isFalse);
    expect(repo.lastError, isNull);
    expect(repo.skippedLines, 0);
  });

  test('add appends, keeps newest first and notifies', () async {
    await repo.load();
    var notifications = 0;
    repo.addListener(() => notifications++);

    now = DateTime(2026, 9, 20, 20);
    await repo.add(BeerSize.third);
    now = DateTime(2026, 9, 20, 21);
    await repo.add(BeerSize.half);

    expect(repo.beers.map((b) => b.ml), [500, 333]);
    expect(notifications, 2);
    expect((await log.readAll()).beers, hasLength(2));
  });

  test('add pushes the widget summary for today', () async {
    await repo.load();
    await repo.add(BeerSize.half);
    expect(bridge.pushes.last.dayKey, '2026-09-20');
    expect(bridge.pushes.last.count, 1);
    expect(bridge.pushes.last.ml, 500);
  });

  test('load sorts a shuffled file newest first', () async {
    await log.append(Beer(id: 'b', ml: 500, at: DateTime(2026, 9, 20, 10)));
    await log.append(Beer(id: 'a', ml: 333, at: DateTime(2026, 9, 19, 10)));
    await repo.load();
    expect(repo.beers.map((b) => b.id), ['b', 'a']);
  });

  test('load surfaces skipped lines', () async {
    await log.file.writeAsString('garbage\n');
    await repo.load();
    expect(repo.skippedLines, 1);
    expect(repo.beers, isEmpty);
  });

  test('load picks up entries written by the widget', () async {
    await repo.load();
    await log.append(Beer(id: 'w', ml: 500, at: DateTime(2026, 9, 20, 22)));
    expect(repo.beers, isEmpty, reason: 'not seen until reload');
    await repo.load();
    expect(repo.beers.single.id, 'w');
  });

  test('remove drops the entry from memory and file', () async {
    await repo.load();
    final beer = await repo.add(BeerSize.third);
    await repo.remove(beer!.id);
    expect(repo.beers, isEmpty);
    expect((await log.readAll()).beers, isEmpty);
  });

  test('remove of an unknown id is a no-op', () async {
    await repo.load();
    await repo.add(BeerSize.third);
    await repo.remove('nope');
    expect(repo.beers, hasLength(1));
  });

  test('restore puts a removed entry back in order', () async {
    await repo.load();
    now = DateTime(2026, 9, 20, 18);
    final first = await repo.add(BeerSize.third);
    now = DateTime(2026, 9, 20, 22);
    await repo.add(BeerSize.half);

    await repo.remove(first!.id);
    expect(repo.beers.map((b) => b.ml), [500]);

    await repo.restore(first);
    expect(repo.beers.map((b) => b.ml), [500, 333]);
    expect((await log.readAll()).beers, hasLength(2));
  });

  test('restoring something already present is a no-op', () async {
    await repo.load();
    final beer = await repo.add(BeerSize.third);
    await repo.restore(beer!);
    expect(repo.beers, hasLength(1));
  });

  test('eraseAll clears memory, file and the widget summary', () async {
    await repo.load();
    await repo.add(BeerSize.half);
    await repo.eraseAll();
    expect(repo.beers, isEmpty);
    expect((await log.readAll()).beers, isEmpty);
    expect(bridge.pushes.last.count, 0);
  });

  test('addAt accepts an explicit time and volume', () async {
    await repo.load();
    final beer = await repo.addAt(ml: 250, at: DateTime(2026, 9, 19, 12));
    expect(beer, isNotNull);
    expect(repo.beers.single.ml, 250);
    expect(repo.beers.single.at, DateTime(2026, 9, 19, 12));
  });

  test('an unwritable log surfaces an error instead of throwing', () async {
    await log.append(Beer(id: 'x', ml: 333, at: now));
    // The parent of this path is a regular file, so mkdir must fail.
    final broken = BeerRepository(
      log: BeerLogFile(File('${log.file.path}/nested/beer_log.ndjson')),
      widget: bridge,
      clock: () => now,
    );
    await broken.load();
    final result = await broken.add(BeerSize.half);
    expect(result, isNull);
    expect(broken.lastError, isNotNull);
  });
}
