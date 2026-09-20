import '../models/beer.dart';

class BeerLogReadResult {
  const BeerLogReadResult({required this.beers, required this.skippedLines});

  static const empty = BeerLogReadResult(beers: <Beer>[], skippedLines: 0);

  /// In file order, oldest first.
  final List<Beer> beers;

  /// Lines that could not be parsed and were dropped.
  final int skippedLines;
}

/// Storage behind [BeerRepository]. Exists so widget tests can swap in an
/// in-memory implementation: `testWidgets` bodies run under FakeAsync, where
/// real `dart:io` futures never complete.
abstract interface class BeerLogStore {
  Future<BeerLogReadResult> readAll();
  Future<void> append(Beer beer);
  Future<void> rewrite(List<Beer> beers);
  Future<void> clear();
}
