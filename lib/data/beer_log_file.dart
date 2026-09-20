import 'dart:io';

import '../models/beer.dart';

class BeerLogReadResult {
  const BeerLogReadResult({required this.beers, required this.skippedLines});

  static const empty = BeerLogReadResult(beers: <Beer>[], skippedLines: 0);

  final List<Beer> beers;
  final int skippedLines;
}

/// Append-only NDJSON log, one JSON object per line. The Kotlin widget
/// appends to the same file (see BeerLog.kt), so the format here is a
/// cross-language contract: change one side and you must change the other.
class BeerLogFile {
  BeerLogFile(this.file);

  final File file;

  Future<BeerLogReadResult> readAll() async {
    if (!file.existsSync()) return BeerLogReadResult.empty;
    final raw = await file.readAsString();
    final beers = <Beer>[];
    var skipped = 0;
    for (final line in raw.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        beers.add(Beer.fromJsonLine(line));
      } on FormatException {
        skipped++;
      }
    }
    return BeerLogReadResult(beers: beers, skippedLines: skipped);
  }

  Future<void> append(Beer beer) async {
    await file.parent.create(recursive: true);
    final prefix = await _needsLeadingNewline() ? '\n' : '';
    await file.writeAsString(
      '$prefix${beer.toJsonLine()}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<void> rewrite(List<Beer> beers) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    final buffer = StringBuffer();
    for (final beer in beers) {
      buffer
        ..write(beer.toJsonLine())
        ..write('\n');
    }
    await temp.writeAsString(buffer.toString(), flush: true);
    await temp.rename(file.path);
  }

  Future<void> clear() => rewrite(const <Beer>[]);

  /// A torn write can only damage the last line. Starting the next record on
  /// a fresh line keeps the damage to that one record.
  Future<bool> _needsLeadingNewline() async {
    if (!file.existsSync()) return false;
    final length = await file.length();
    if (length == 0) return false;
    final handle = await file.open();
    try {
      await handle.setPosition(length - 1);
      final last = await handle.read(1);
      return last.isNotEmpty && last.first != 0x0A;
    } finally {
      await handle.close();
    }
  }
}
