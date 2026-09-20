import 'dart:convert';
import 'dart:math';

import 'beer_size.dart';

final Random _defaultRandom = Random();

/// `<epochMillis>-<4 hex>`. Generated identically in Kotlin (see BeerLog.kt)
/// so widget-logged and app-logged entries are indistinguishable.
String newBeerId(DateTime at, Random random) {
  final suffix = random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
  return '${at.millisecondsSinceEpoch}-$suffix';
}

class Beer {
  const Beer({required this.id, required this.ml, required this.at});

  factory Beer.create({
    required int ml,
    required DateTime at,
    Random? random,
  }) {
    final local = at.isUtc ? at.toLocal() : at;
    return Beer(
      id: newBeerId(local, random ?? _defaultRandom),
      ml: ml,
      at: local,
    );
  }

  /// Throws [FormatException] on anything it cannot read. Callers that read
  /// the log file catch this and skip the line.
  factory Beer.fromJsonLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('empty line');
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('not a json object', trimmed);
    }
    final id = decoded['id'];
    final ml = decoded['ml'];
    final at = decoded['at'];
    if (id is! String || id.isEmpty) {
      throw FormatException('bad id', trimmed);
    }
    if (ml is! int || ml <= 0) {
      throw FormatException('bad ml', trimmed);
    }
    if (at is! int) {
      throw FormatException('bad at', trimmed);
    }
    return Beer(id: id, ml: ml, at: DateTime.fromMillisecondsSinceEpoch(at));
  }

  final String id;
  final int ml;

  /// Always local time. Persisted as epoch millis.
  final DateTime at;

  BeerSize? get size => BeerSize.fromMl(ml);

  double get liters => ml / 1000;

  Map<String, Object?> toJsonMap() => <String, Object?>{
        'id': id,
        'ml': ml,
        'at': at.millisecondsSinceEpoch,
      };

  String toJsonLine() => jsonEncode(toJsonMap());

  @override
  bool operator ==(Object other) => other is Beer && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Beer($id, ${ml}ml, $at)';
}
