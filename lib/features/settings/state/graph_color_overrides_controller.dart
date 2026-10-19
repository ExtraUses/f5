import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Persistence layer for per-graph custom color overrides.
///
/// Backed by a dedicated Hive box (`graph_color_overrides`) keyed by a
/// stable string id per analytical widget. Stored values are ARGB32 ints
/// so they round-trip cleanly through JSON backups.
///
/// The controller exposes a tiny read/write API plus a [resolve] helper
/// that returns either the user's override (when set) or the supplied
/// Material You default. This is the single hook consumed by every
/// chart widget on the Focus Stats screen.
class GraphColorOverridesController extends ChangeNotifier {
  GraphColorOverridesController() {
    _load();
  }

  late Box _box;
  Map<String, int> _cache = const {};
  bool _ready = false;

  /// True once the underlying Hive box has finished loading. The Focus
  /// Stats screen waits on this before rendering colored charts so the
  /// override applies on the very first paint.
  bool get isReady => _ready;

  Future<void> _load() async {
    _box = await Hive.openBox(boxName);
    _cache = {
      for (final key in _box.keys)
        if (key is String && _box.get(key) is int)
          key: _box.get(key) as int,
    };
    _ready = true;
    notifyListeners();
  }

  /// Hive box name. Public so the backup service can read the box
  /// directly when the controller hasn't been instantiated yet
  /// (e.g. during the isolate export path).
  static const String boxName = 'graph_color_overrides';

  /// Stable graph ids used across the app. Centralized here so we can
  /// audit / rename them in one place.
  static const focusRangeBars = 'focus_stats.range_bars';
  static const focusConsistencyGauge = 'focus_stats.consistency_gauge';
  static const focusLabelTotals = 'focus_stats.label_totals';
  static const focusSegmentedBars = 'focus_stats.segmented_bars';

  /// Returns the user's override for [graphId], or `null` when no
  /// override is set (caller should fall back to the Material You
  /// accent).
  Color? overrideFor(String graphId) {
    final v = _cache[graphId];
    return v == null ? null : Color(v);
  }

  /// Returns the override color when set, otherwise [defaultColor].
  /// The single entry point used by every chart widget.
  Color resolve(String graphId, Color defaultColor) {
    final v = _cache[graphId];
    return v == null ? defaultColor : Color(v);
  }

  Future<void> setOverride(String graphId, Color color) async {
    _cache = Map<String, int>.of(_cache)..[graphId] = color.toARGB32();
    await _box.put(graphId, color.toARGB32());
    notifyListeners();
  }

  Future<void> clearOverride(String graphId) async {
    if (!_cache.containsKey(graphId)) return;
    _cache = Map<String, int>.of(_cache)..remove(graphId);
    await _box.delete(graphId);
    notifyListeners();
  }

  /// Snapshot of all overrides, for backup export. Keys are graph ids,
  /// values are ARGB32 ints.
  Map<String, int> snapshot() => Map<String, int>.of(_cache);

  /// Bulk restore from a backup payload. Wipes the box and writes the
  /// supplied map. Used by the import path.
  Future<void> restore(Map<String, int> payload) async {
    await _box.clear();
    for (final entry in payload.entries) {
      await _box.put(entry.key, entry.value);
    }
    _cache = Map<String, int>.of(payload);
    notifyListeners();
  }
}
