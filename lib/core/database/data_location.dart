import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class DataLocation {
  const DataLocation._();

  static const boxes = [
    'habits',
    'settings',
    'categories',
    'notes',
    'focus',
    'todos',
    'todo_tags',
  ];

  static const folders = [
    'covers',
    'journey',
    'todos',
    'focus',
    'tracks',
    'alerts',
    'backups',
    'widget_icons',
  ];

  static const _fileName = 'data-location.json';

  static Directory? _support;
  static String? _rewriteFrom;

  static String? get rewriteFrom => _rewriteFrom;

  static Directory get portableDir =>
      Directory(
        '${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}StreakData',
      );

  static bool holdsData(Directory dir) =>
      File('${dir.path}/habits.hive').existsSync();

  static File _file(Directory support) => File('${support.path}/$_fileName');

  static Map<String, dynamic> _read(Directory support) {
    try {
      final file = _file(support);
      if (!file.existsSync()) return const {};
      return Map<String, dynamic>.from(
        json.decode(file.readAsStringSync()) as Map,
      );
    } catch (e) {
      debugPrint('Unreadable data location: $e');
      return const {};
    }
  }

  static void _write(Directory support, Map<String, String> entry) {
    if (!support.existsSync()) support.createSync(recursive: true);
    _file(support).writeAsStringSync(json.encode(entry), flush: true);
  }

  static Future<Directory?> resolve(Directory support) async {
    _support = support;
    final entry = _read(support);
    final path = entry['path'] as String?;
    final moveFrom = entry['moveFrom'] as String?;
    final rewriteFrom = entry['rewriteFrom'] as String?;

    if (path != null && moveFrom != null) {
      return _carry(support, Directory(moveFrom), Directory(path));
    }
    if (path != null && rewriteFrom != null) {
      _rewriteFrom = rewriteFrom;
      return Directory(path);
    }
    if (holdsData(portableDir)) return portableDir;
    if (path != null && Directory(path).existsSync()) return Directory(path);
    return null;
  }

  static void schedule({required Directory from, required Directory to}) {
    final support = _support;
    if (support == null) throw StateError('Data location not resolved yet');
    _write(support, {'path': to.path, 'moveFrom': from.path});
  }

  static Future<Directory> _carry(
    Directory support,
    Directory from,
    Directory to,
  ) async {
    final copied = <FileSystemEntity>[];
    try {
      if (!to.existsSync()) to.createSync(recursive: true);
      for (final source in _ours(from)) {
        final name = source.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        final target = '${to.path}/$name';
        if (source is File) {
          copied.add(await _copyFile(source, File(target)));
        } else if (source is Directory) {
          copied.add(Directory(target));
          await _copyTree(source, Directory(target));
        }
      }
      _write(support, {'path': to.path, 'rewriteFrom': from.path});
      _rewriteFrom = from.path;
      return to;
    } catch (e) {
      debugPrint('Moving the data failed, staying in ${from.path}: $e');
      for (final entity in copied) {
        try {
          if (entity.existsSync()) entity.deleteSync(recursive: true);
        } catch (_) {}
      }
      _write(support, {'path': from.path});
      return from;
    }
  }

  static Iterable<FileSystemEntity> _ours(Directory dir) sync* {
    for (final box in boxes) {
      final file = File('${dir.path}/$box.hive');
      if (file.existsSync()) yield file;
    }
    for (final folder in folders) {
      final sub = Directory('${dir.path}/$folder');
      if (sub.existsSync()) yield sub;
    }
    for (final entity in dir.listSync()) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (entity is File &&
          (name.startsWith('profile_') || name.startsWith('bg_'))) {
        yield entity;
      }
    }
  }

  static Future<File> _copyFile(File source, File target) async {
    final copy = await source.copy(target.path);
    if (copy.lengthSync() != source.lengthSync()) {
      throw FileSystemException('Copy came out a different size', target.path);
    }
    return copy;
  }

  static Future<void> _copyTree(Directory source, Directory target) async {
    if (!target.existsSync()) target.createSync(recursive: true);
    for (final entity in source.listSync()) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (entity is File) {
        await _copyFile(entity, File('${target.path}/$name'));
      } else if (entity is Directory) {
        await _copyTree(entity, Directory('${target.path}/$name'));
      }
    }
  }

  static Object? rewrite(Object? value, String from, String to) {
    if (value is String) return _rewritePath(value, from, to);
    if (value is List) {
      final items = [for (final item in value) rewrite(item, from, to)];
      final same = Iterable.generate(value.length)
          .every((i) => identical(items[i], value[i]));
      return same ? value : items;
    }
    if (value is Map) {
      final entries = {
        for (final entry in value.entries)
          entry.key: rewrite(entry.value, from, to),
      };
      final same = value.keys.every((k) => identical(entries[k], value[k]));
      return same ? value : entries;
    }
    return value;
  }

  static String _rewritePath(String value, String from, String to) {
    final plain = value.replaceAll(r'\', '/');
    final root = from.replaceAll(r'\', '/');
    if (plain != root && !plain.startsWith('$root/')) return value;
    return '$to${value.substring(from.length)}';
  }

  static void finish() {
    final support = _support;
    final from = _rewriteFrom;
    if (support == null || from == null) return;
    final old = Directory(from);
    if (old.existsSync()) {
      for (final entity in _ours(old).toList()) {
        try {
          entity.deleteSync(recursive: true);
        } catch (e) {
          debugPrint('Could not clear the old copy of $entity: $e');
        }
      }
      for (final lock in old.listSync().whereType<File>()) {
        if (lock.path.endsWith('.lock')) {
          try {
            lock.deleteSync();
          } catch (_) {}
        }
      }
      try {
        if (old.listSync().isEmpty) old.deleteSync();
      } catch (_) {}
    }
    final path = _read(support)['path'] as String?;
    if (path != null) _write(support, {'path': path});
    _rewriteFrom = null;
  }
}
