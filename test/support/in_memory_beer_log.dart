import 'package:beer_count/data/beer_log_store.dart';
import 'package:beer_count/models/beer.dart';

/// Synchronous stand-in for [BeerLogFile] used by widget tests.
///
/// `testWidgets` bodies run under FakeAsync, where real `dart:io` futures
/// never complete, so anything touching the filesystem would hang the test.
class InMemoryBeerLog implements BeerLogStore {
  InMemoryBeerLog({List<Beer>? seed, this.skippedLines = 0})
      : _beers = [...?seed];

  final List<Beer> _beers;

  /// Simulates unreadable lines in the on-disk log.
  int skippedLines;

  @override
  Future<BeerLogReadResult> readAll() async =>
      BeerLogReadResult(beers: [..._beers], skippedLines: skippedLines);

  @override
  Future<void> append(Beer beer) async => _beers.add(beer);

  @override
  Future<void> rewrite(List<Beer> beers) async {
    _beers
      ..clear()
      ..addAll(beers);
  }

  @override
  Future<void> clear() async => _beers.clear();
}
