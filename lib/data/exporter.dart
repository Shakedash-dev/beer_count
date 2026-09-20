import 'dart:convert';

import '../models/beer.dart';

List<Beer> _oldestFirst(List<Beer> beers) =>
    [...beers]..sort((a, b) => a.at.compareTo(b.at));

String _isoLocal(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Ids and size labels contain no commas or quotes by construction, so no
/// escaping is needed. Add quoting here if a field ever can.
String beersToCsv(List<Beer> beers) {
  final buffer = StringBuffer('id,logged_at_local,epoch_ms,ml,size\n');
  for (final beer in _oldestFirst(beers)) {
    buffer
      ..write(beer.id)
      ..write(',')
      ..write(_isoLocal(beer.at))
      ..write(',')
      ..write(beer.at.millisecondsSinceEpoch)
      ..write(',')
      ..write(beer.ml)
      ..write(',')
      ..write(beer.size?.label ?? 'other')
      ..write('\n');
  }
  return buffer.toString();
}

String beersToJson(List<Beer> beers) => const JsonEncoder.withIndent('  ')
    .convert(_oldestFirst(beers).map((b) => b.toJsonMap()).toList());
