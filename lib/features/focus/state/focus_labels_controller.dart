import 'dart:async';

import 'package:flutter/material.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/icons/habit_icons.dart';
import 'package:streak/features/focus/data/focus_label.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:uuid/uuid.dart';

/// Controller for the standalone [FocusLabel] entity.
///
/// Mirrors the [CategoriesController] pattern: a [ChangeNotifier] that
/// loads its list from [LocalStore] on construction, holds the canonical
/// in-memory copy, and persists every mutation through [LocalStore].
///
/// Registered as a singleton in `main.dart` via [MultiProvider] so that the
/// label picker, the focus setup screen, and (in Phase 3) the analytics
/// widgets all observe the same source of truth.
class FocusLabelsController extends ChangeNotifier {
  FocusLabelsController() {
    _labels = LocalStore.readFocusLabels();
    unawaited(_migrateLegacy());
  }

  final _uuid = const Uuid();
  late List<FocusLabel> _labels;

  /// Cached id → label lookup. Rebuilt on every [notifyListeners] call by
  /// way of [_view] being nulled.
  Map<String, FocusLabel>? _index;

  List<FocusLabel> get labels => List.unmodifiable(_labels);

  /// Labels visible in the picker (excludes archived).
  List<FocusLabel> get visible {
    final kept = _labels.where((l) => !l.isArchived).toList();
    kept.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(kept);
  }

  /// All labels including archived — used by the analytics layer so that
  /// historical sessions still resolve their color even if the label was
  /// later archived.
  List<FocusLabel> get all {
    final sorted = [..._labels];
    sorted.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(sorted);
  }

  FocusLabel? byId(String id) {
    if (id.isEmpty) return null;
    return (_index ??= {for (final l in _labels) l.id: l})[id];
  }

  /// Convenience for the picker: returns the label name or the empty string
  /// when the label was deleted (so legacy sessions still render with a
  /// readable fallback rather than a UUID).
  String nameOf(String id) => byId(id)?.name ?? '';

  /// Convenience for the analytics widgets: returns the label color or the
  /// app's primary color when the label was deleted. This keeps the stacked
  /// bar chart drawable even for orphaned sessions.
  Color colorOf(String id, {Color fallback = const Color(0xFF7C3AED)}) =>
      byId(id)?.color ?? fallback;

  /// Convenience for the focus setup screen: returns the label id matching
  /// the legacy free-form [FocusSession.label] string. Used during the
  /// transition window while sessions may still carry the old field.
  String idForName(String name) {
    if (name.isEmpty) return '';
    final match = _labels.firstWhere(
      (l) => l.name == name,
      orElse: () => FocusLabel(
        id: '',
        name: name,
        color: const Color(0xFF7C3AED),
      ),
    );
    return match.id;
  }

  Future<FocusLabel> create({
    required String name,
    required Color color,
    String icon = HabitIcons.defaultIcon,
  }) async {
    final trimmed = name.trim();
    final label = FocusLabel(
      id: _uuid.v4(),
      name: trimmed.isEmpty ? 'Label' : trimmed,
      color: color,
      icon: icon,
      order: _labels.fold(0, (top, l) => l.order >= top ? l.order + 1 : top),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    _labels.add(label);
    await LocalStore.writeFocusLabel(label);
    notifyListeners();
    return label;
  }

  Future<void> update(FocusLabel updated) async {
    final index = _labels.indexWhere((l) => l.id == updated.id);
    if (index == -1) return;
    final withTimestamp = updated.copyWith(updatedAt: DateTime.now().toUtc());
    _labels[index] = withTimestamp;
    await LocalStore.writeFocusLabel(withTimestamp);
    notifyListeners();
  }

  Future<void> reorder(List<FocusLabel> ordered) async {
    final byId = {for (final l in _labels) l.id: l};
    final rebuilt = <FocusLabel>[];
    for (final (index, label) in ordered.indexed) {
      final source = byId[label.id];
      if (source == null) continue;
      rebuilt.add(source.copyWith(order: index));
    }
    // Append any labels that were not included in the reorder list
    // (e.g. archived ones) so they survive the operation.
    final seen = {for (final l in rebuilt) l.id};
    for (final l in _labels) {
      if (!seen.contains(l.id)) rebuilt.add(l);
    }
    _labels = rebuilt;
    notifyListeners();
    for (final label in _labels) {
      await LocalStore.writeFocusLabel(label);
    }
  }

  Future<void> archive(String id) async {
    final index = _labels.indexWhere((l) => l.id == id);
    if (index == -1) return;
    final archived =
        _labels[index].copyWith(isArchived: true, updatedAt: DateTime.now().toUtc());
    _labels[index] = archived;
    await LocalStore.writeFocusLabel(archived);
    notifyListeners();
  }

  Future<void> unarchive(String id) async {
    final index = _labels.indexWhere((l) => l.id == id);
    if (index == -1) return;
    final restored =
        _labels[index].copyWith(isArchived: false, updatedAt: DateTime.now().toUtc());
    _labels[index] = restored;
    await LocalStore.writeFocusLabel(restored);
    notifyListeners();
  }

  /// Hard delete. The caller is responsible for confirming with the user.
  /// Sessions that referenced this label will simply render with the
  /// fallback color/name — they are NOT cascade-deleted.
  Future<void> remove(String id) async {
    _labels.removeWhere((l) => l.id == id);
    await LocalStore.removeFocusLabel(id);
    notifyListeners();
  }

  void reload() {
    _labels = LocalStore.readFocusLabels();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _index = null;
    super.notifyListeners();
  }

  // -------------------------------------------------------------------
  // Legacy migration — runs once on first launch after upgrade.
  // -------------------------------------------------------------------

  /// Promotes the old `focusLabels` settings map (which keyed free-form
  /// label strings by `habitId`) into standalone [FocusLabel] entities,
  /// and backfills any pre-existing focus sessions whose `labelId` is
  /// empty onto either a matched label (by name) or the auto-created
  /// `free-session` default.
  ///
  /// Idempotent — guarded by [LocalStore.focusLabelsMigrated] so it only
  /// ever runs once per install.
  Future<void> _migrateLegacy() async {
    if (LocalStore.focusLabelsMigrated) return;

    // 1. Ensure the "Free Session" default exists. This swallows every
    //    legacy session that had no habit and no free-form label.
    if (byId(FocusLabel.freeSessionId) == null) {
      final free = FocusLabel(
        id: FocusLabel.freeSessionId,
        name: FocusLabel.freeSessionName,
        color: const Color(0xFF6E6E73),
        icon: HabitIcons.defaultIcon,
        order: -1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      _labels.add(free);
      await LocalStore.writeFocusLabel(free);
    }

    // 2. Promote each legacy free-form label string into a FocusLabel.
    final legacyMap = LocalStore.settingMap('focusLabels');
    final renamed = <String, String>{};
    for (final entry in legacyMap.entries) {
      final habitId = entry.key;
      final list = entry.value;
      if (list is! List) continue;
      for (final raw in list) {
        if (raw is! String) continue;
        final name = raw.trim();
        if (name.isEmpty) continue;
        final existing = _labels.firstWhere(
          (l) => l.name.toLowerCase() == name.toLowerCase(),
          orElse: () => FocusLabel(
            id: '',
            name: name,
            color: const Color(0xFF7C3AED),
          ),
        );
        if (existing.id.isEmpty) {
          final created = await create(
            name: name,
            color: const Color(0xFF7C3AED),
            icon: HabitIcons.defaultIcon,
          );
          renamed['$habitId|$name'] = created.id;
        } else {
          renamed['$habitId|$name'] = existing.id;
        }
      }
    }

    // 3. Backfill focus sessions. Each session that had a non-empty legacy
    //    `label` string gets matched to a FocusLabel by name. Sessions that
    //    had no label and no habit get the `free-session` default.
    final sessions = LocalStore.readFocusSessions();
    final dirty = <FocusSession>[];
    for (final s in sessions) {
      if (s.labelId.isNotEmpty) continue;
      String labelId = '';
      if (s.label.isNotEmpty) {
        final match = _labels.firstWhere(
          (l) => l.name.toLowerCase() == s.label.toLowerCase(),
          orElse: () => FocusLabel(
            id: '',
            name: s.label,
            color: const Color(0xFF7C3AED),
          ),
        );
        if (match.id.isNotEmpty) {
          labelId = match.id;
        } else {
          final created = await create(
            name: s.label,
            color: const Color(0xFF7C3AED),
            icon: HabitIcons.defaultIcon,
          );
          labelId = created.id;
        }
      } else if (s.habitId.isEmpty) {
        labelId = FocusLabel.freeSessionId;
      }
      if (labelId.isEmpty) continue;
      dirty.add(s.copyWith(labelId: labelId));
    }
    for (final s in dirty) {
      await LocalStore.writeFocusSession(s);
    }

    await LocalStore.markFocusLabelsMigrated();
    notifyListeners();
  }
}
