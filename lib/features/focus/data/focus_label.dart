import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:streak/core/icons/habit_icons.dart';

/// A standalone Focus Label.
///
/// Decoupled from [Habit] so that focus sessions can be tagged with an
/// arbitrary activity ("Deep Work", "Reading", "Exercise") without requiring
/// a habit to exist. The label's [color] is preserved verbatim through
/// backup/restore and is used as the segment color in the analytics
/// stacked-bar chart.
///
/// Mirrors the serialization pattern established by [Category]:
/// Hive stores a JSON [String]; no [TypeAdapter] is registered. This keeps
/// the schema migration path identical to every other model in the app and
/// survives Hive CE minor-version bumps without codegen.
class FocusLabel {
  FocusLabel({
    required this.id,
    required this.name,
    required this.color,
    this.icon = HabitIcons.defaultIcon,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
    this.isArchived = false,
  });

  /// UUID v4. The literal `'free-session'` is reserved for the migration
  /// default label that swallows legacy `habitId = null` focus sessions.
  final String id;

  /// Display name, 1–30 characters. Not unique — duplicates are allowed
  /// because the [id] is the canonical key.
  final String name;

  /// ARGB32 color. Persisted as `int` so it round-trips through JSON without
  /// lossy alpha conversions. Used directly by the analytics widgets as the
  /// segment color.
  final Color color;

  /// Icon key from [HabitIcons.all]. Stored as a string so that adding new
  /// icons does not require a schema migration — unknown keys fall back to
  /// the project's default (`sparkles`).
  final String icon;

  /// Manual sort order. The lowest value renders first in the picker.
  final int order;

  /// Creation timestamp (UTC ISO-8601). Populated on first [FocusLabelsController.create]
  /// and preserved across edits.
  final DateTime? createdAt;

  /// Last-modified timestamp. Bumped on every [FocusLabelsController.update].
  final DateTime? updatedAt;

  /// Soft-archive flag. Archived labels are hidden from the picker but
  /// remain in the database so that historical focus sessions still resolve
  /// their color and name.
  final bool isArchived;

  static const freeSessionId = 'free-session';
  static const freeSessionName = 'Free Session';
  static const maxNameLength = 30;

  FocusLabel copyWith({
    String? name,
    Color? color,
    String? icon,
    int? order,
    DateTime? updatedAt,
    bool? isArchived,
  }) =>
      FocusLabel(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        order: order ?? this.order,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isArchived: isArchived ?? this.isArchived,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'icon': icon,
        'order': order,
        if (createdAt != null)
          'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (isArchived) 'isArchived': true,
      };

  factory FocusLabel.fromMap(Map<String, dynamic> map) => FocusLabel(
        id: map['id'] as String,
        name: (map['name'] ?? '') as String,
        color: Color((map['color'] ?? 0xFF7C3AED) as int),
        icon: (map['icon'] ?? HabitIcons.defaultIcon) as String,
        order: ((map['order'] ?? 0) as num).toInt(),
        createdAt: _parseDate(map['createdAt']),
        updatedAt: _parseDate(map['updatedAt']),
        isArchived: map['isArchived'] == true,
      );

  String toJson() => json.encode(toMap());

  factory FocusLabel.fromJson(String source) =>
      FocusLabel.fromMap(json.decode(source) as Map<String, dynamic>);

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// Material You — derives a tonal palette entry that pairs with the
  /// label's [color]. Used by the picker chip background when a label is
  /// selected: the chip fills with a translucent version of this color so
  /// the user sees exactly the hue they assigned.
  Color chipTint() => color.withValues(alpha: 0.18);

  /// Foreground color that stays legible against the [chipTint] background.
  /// Mirrors the contrast rule used by [_Swatch] in color_picker.dart.
  Color chipForeground() =>
      color.computeLuminance() > 0.55 ? const Color(0xFF1C1C1E) : color;
}

/// Icon registry for focus labels. Delegates to the project's canonical
/// [HabitIcons] registry so that any Lucide icon supported anywhere in the
/// app is available here too — no duplicated icon tables to drift out of
/// sync. The only addition is a sensible curated "common" subset exposed
/// by [FocusLabelIcons.commonNames] for the picker's quick grid.
class FocusLabelIcons {
  const FocusLabelIcons._();

  /// Curated subset for the editor's quick-pick grid. Chosen to cover the
  /// most common focus activities (work, study, exercise, meditation…).
  /// The full [HabitIcons] registry remains accessible by typing the icon
  /// name in a future release.
  ///
  /// Every name in this list must exist as a key in [HabitIcons.all];
  /// otherwise [HabitIcons.resolve] silently falls back to the default
  /// icon and the user sees a different glyph than the one they picked.
  static const List<String> commonNames = [
    'sparkles',
    'target',
    'brain',
    'zap',
    'book',
    'briefcase',
    'code',
    'coffee',
    'dumbbell',
    'flame',
    'flower2',
    'graduationCap',
    'heart',
    'house',
    'leaf',
    'moon',
    'music',
    'palette',
    'penLine',
    'rocket',
    'footprints',
    'sun',
    'trophy',
    'utensils',
    'wallet',
    'clock',
    'wind',
    'headphones',
    'smartphone',
  ];

  static List<String> get names => commonNames;

  static IconData resolve(String name) => HabitIcons.resolve(name);

  static bool isIcon(String name) => HabitIcons.isIcon(name);
}

