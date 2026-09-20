import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/beer.dart';
import '../models/beer_size.dart';
import 'beer_log_file.dart';
import 'widget_bridge.dart';

/// Owns the in-memory log and is the only place that mutates it.
/// Entries are always exposed newest first.
class BeerRepository extends ChangeNotifier {
  BeerRepository({
    required this.log,
    required this.widget,
    DateTime Function()? clock,
    Random? random,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final BeerLogFile log;
  final WidgetBridge widget;
  final DateTime Function() _clock;
  final Random _random;

  List<Beer> _beers = <Beer>[];
  int _skippedLines = 0;
  bool _isLoading = false;
  String? _lastError;

  List<Beer> get beers => List<Beer>.unmodifiable(_beers);
  int get skippedLines => _skippedLines;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// Re-reads the file from disk. Called on every app resume, which is how
  /// beers logged from the home-screen widget reach the UI.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await log.readAll();
      _beers = _sorted(result.beers);
      _skippedLines = result.skippedLines;
      _lastError = null;
    } on Object catch (e) {
      _lastError = '$e';
    } finally {
      _isLoading = false;
    }
    await _pushSummary();
    notifyListeners();
  }

  Future<Beer?> add(BeerSize size) => addAt(ml: size.ml, at: _clock());

  Future<Beer?> addAt({required int ml, required DateTime at}) async {
    final beer = Beer.create(ml: ml, at: at, random: _random);
    if (!await _tryAppend(beer)) return null;
    _beers = _sorted([..._beers, beer]);
    await _finish();
    return beer;
  }

  /// Undo for a swipe-delete.
  Future<void> restore(Beer beer) async {
    if (_beers.any((b) => b.id == beer.id)) return;
    if (!await _tryAppend(beer)) return;
    _beers = _sorted([..._beers, beer]);
    await _finish();
  }

  Future<void> remove(String id) async {
    final remaining = _beers.where((b) => b.id != id).toList();
    if (remaining.length == _beers.length) return;
    try {
      await log.rewrite(remaining.reversed.toList());
    } on Object catch (e) {
      _lastError = '$e';
      notifyListeners();
      return;
    }
    _beers = remaining;
    await _finish();
  }

  Future<void> eraseAll() async {
    try {
      await log.clear();
    } on Object catch (e) {
      _lastError = '$e';
      notifyListeners();
      return;
    }
    _beers = <Beer>[];
    _skippedLines = 0;
    await _finish();
  }

  Future<bool> _tryAppend(Beer beer) async {
    try {
      await log.append(beer);
      return true;
    } on Object catch (e) {
      _lastError = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _finish() async {
    _lastError = null;
    await _pushSummary();
    notifyListeners();
  }

  Future<void> _pushSummary() async {
    try {
      await widget.push(summarizeToday(_beers, _clock()));
    } on Object {
      // The widget cache is best-effort. Never fail a log because of it.
    }
  }

  static List<Beer> _sorted(List<Beer> beers) =>
      [...beers]..sort((a, b) => b.at.compareTo(a.at));
}
