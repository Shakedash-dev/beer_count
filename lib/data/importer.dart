import 'dart:convert';

import '../models/beer.dart';

class BeerImportResult {
  const BeerImportResult({required this.beers, required this.skipped});

  final List<Beer> beers;

  /// Records inside the array that could not be read.
  final int skipped;
}

/// Reads what [beersToJson] writes: a JSON array of `{id, ml, at}` objects.
/// Throws [FormatException] when the text is not such an array at all. Bad
/// records inside it are skipped and counted, like damaged log lines.
BeerImportResult beersFromJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List<Object?>) {
    throw const FormatException('not a json array');
  }
  final beers = <Beer>[];
  var skipped = 0;
  for (final entry in decoded) {
    try {
      if (entry is! Map<String, Object?>) {
        throw const FormatException('not a json object');
      }
      beers.add(Beer.fromJsonMap(entry));
    } on FormatException {
      skipped++;
    }
  }
  return BeerImportResult(beers: beers, skipped: skipped);
}
