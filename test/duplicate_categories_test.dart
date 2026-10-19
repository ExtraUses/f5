import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/features/habits/data/category.dart';

import 'support/app_harness.dart';

Category _category(String id, String name, {int order = 0}) => Category(
      id: id,
      name: name,
      color: const Color(0xFF34C759),
      order: order,
    );

void main() {
  useEmptyStore();

  test('a category from another device with the same name stays out', () async {
    await LocalStore.writeCategory(_category('phone', 'Health'));
    await LocalStore.mergeCategory(_category('pc', 'Health'));
    await LocalStore.mergeCategory(_category('pc-2', ' health '));
    await LocalStore.mergeCategory(_category('pc-3', 'Reading'));

    final names = LocalStore.readCategories().map((c) => c.name).toList();
    expect(names, hasLength(2));
    expect(names, containsAll(['Health', 'Reading']));
  });

  test('repeated categories already stored collapse into one', () async {
    await LocalStore.writeCategory(_category('a', 'Health', order: 2));
    await LocalStore.writeCategory(_category('b', 'Health'));
    await LocalStore.writeCategory(_category('c', 'Health', order: 1));
    await LocalStore.writeCategory(_category('d', 'Finance'));

    final once = await LocalStore.readCategoriesOnce();

    expect(once.map((c) => c.name), unorderedEquals(['Health', 'Finance']));
    expect(once.firstWhere((c) => c.name == 'Health').id, 'b');
    expect(LocalStore.readCategories(), hasLength(2));
  });
}
