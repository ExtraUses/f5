import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streak/core/database/data_location.dart';

void main() {
  late Directory root;
  late Directory support;
  late Directory from;
  late Directory to;

  setUp(() {
    root = Directory.systemTemp.createTempSync('streak_move');
    support = Directory('${root.path}/support')..createSync();
    from = Directory('${root.path}/old')..createSync();
    to = Directory('${root.path}/new');
    File('${from.path}/habits.hive').writeAsStringSync('habits');
    File('${from.path}/settings.hive').writeAsStringSync('settings');
    File('${from.path}/profile_1.jpg').writeAsStringSync('me');
    Directory('${from.path}/covers').createSync();
    File('${from.path}/covers/1.jpg').writeAsStringSync('cover');
    File('${from.path}/notes.txt').writeAsStringSync('not ours');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('nothing chosen keeps the old place', () async {
    expect(await DataLocation.resolve(support), isNull);
  });

  test('a move copies our files, rewrites the paths and clears the old ones',
      () async {
    await DataLocation.resolve(support);
    DataLocation.schedule(from: from, to: to);

    final moved = await DataLocation.resolve(support);
    expect(moved?.path, to.path);
    expect(File('${to.path}/habits.hive').readAsStringSync(), 'habits');
    expect(File('${to.path}/covers/1.jpg').readAsStringSync(), 'cover');
    expect(File('${to.path}/profile_1.jpg').existsSync(), isTrue);
    expect(File('${to.path}/notes.txt').existsSync(), isFalse);
    expect(DataLocation.rewriteFrom, from.path);

    final cover = {'coverPath': '${from.path}/covers/1.jpg', 'name': 'Run'};
    final rewritten = DataLocation.rewrite(cover, from.path, to.path) as Map;
    expect(rewritten['coverPath'], '${to.path}/covers/1.jpg');
    expect(rewritten['name'], 'Run');
    final untouched = {'name': 'Run'};
    expect(identical(DataLocation.rewrite(untouched, from.path, to.path), untouched),
        isTrue);

    DataLocation.finish();
    expect(File('${from.path}/habits.hive').existsSync(), isFalse);
    expect(Directory('${from.path}/covers').existsSync(), isFalse);
    expect(File('${from.path}/notes.txt').existsSync(), isTrue);
    expect(DataLocation.rewriteFrom, isNull);

    expect((await DataLocation.resolve(support))?.path, to.path);
  });
}
