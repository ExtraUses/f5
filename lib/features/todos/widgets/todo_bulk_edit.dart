import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/settings/widgets/minimal_settings_widgets.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/state/todos_controller.dart';
import 'package:streak/features/todos/widgets/todo_sticker.dart';
import 'package:streak/features/todos/widgets/todo_tag_sheet.dart';

Future<void> editTodos(BuildContext context, List<String> ids) {
  final l10n = context.l10n;
  return showOptionSheet(
    context,
    title: l10n.edit,
    options: [
      l10n.todo_priority,
      l10n.todo_tags,
      l10n.todo_project,
      l10n.todo_date,
    ],
    index: -1,
    onSelected: (index) => switch (index) {
      0 => _pickPriority(context, ids),
      1 => _pickTags(context, ids),
      2 => _pickProject(context, ids),
      _ => _pickDate(context, ids),
    },
  );
}

List<Todo> _current(BuildContext context, List<String> ids) {
  final todos = context.read<TodosController>();
  return [for (final id in ids) ?todos.byId(id)];
}

Future<void> _apply(
  BuildContext context,
  List<String> ids,
  Todo Function(Todo todo) change,
) async {
  final controller = context.read<TodosController>();
  final todos = _current(context, ids);
  for (final todo in todos) {
    await controller.update(change(todo));
  }
}

T? _shared<T>(List<Todo> todos, T Function(Todo todo) value) {
  if (todos.isEmpty) return null;
  final first = value(todos.first);
  return todos.every((todo) => value(todo) == first) ? first : null;
}

Future<void> _pickPriority(BuildContext context, List<String> ids) =>
    showTodoPriorityPicker(
      context,
      selected: _shared(_current(context, ids), (t) => t.priority) ??
          TodoPriority.none,
      onPicked: (priority) =>
          _apply(context, ids, (todo) => todo.copyWith(priority: priority)),
    );

Future<void> _pickProject(BuildContext context, List<String> ids) =>
    showTodoProjectPicker(
      context,
      selected: _shared(_current(context, ids), (t) => t.project) ?? '',
      onChanged: (project) =>
          _apply(context, ids, (todo) => todo.copyWith(project: project)),
    );

Future<void> _pickTags(BuildContext context, List<String> ids) {
  final todos = _current(context, ids);
  var common = todos.isEmpty
      ? <String>{}
      : todos
          .map((todo) => todo.tags.toSet())
          .reduce((a, b) => a.intersection(b));
  return showTodoTagPicker(
    context,
    selected: common.toList(),
    onChanged: (picked) {
      final next = picked.toSet();
      final added = next.difference(common);
      final removed = common.difference(next);
      common = next;
      _apply(
        context,
        ids,
        (todo) => todo.copyWith(
          tags: [
            for (final tag in todo.tags)
              if (!removed.contains(tag)) tag,
            for (final tag in added)
              if (!todo.tags.contains(tag)) tag,
          ],
        ),
      );
    },
  );
}

Future<void> _pickDate(BuildContext context, List<String> ids) {
  final l10n = context.l10n;
  final today = AppClock.today();
  void setDate(String date) => _apply(
        context,
        ids,
        (todo) => todo.copyWith(date: date, clearMinutes: date.isEmpty),
      );
  return showOptionSheet(
    context,
    title: l10n.todo_date,
    options: [l10n.today, l10n.tomorrow, l10n.pick_a_date, l10n.todo_no_date],
    index: -1,
    onSelected: (index) async {
      switch (index) {
        case 0 || 1:
          setDate(today.addDays(index).dayKey);
        case 2:
          final picked = await showDatePicker(
            context: context,
            initialDate: today,
            firstDate: DateTime(today.year - 1),
            lastDate: DateTime(today.year + 5),
          );
          if (picked != null && context.mounted) setDate(picked.dayKey);
        default:
          setDate('');
      }
    },
  );
}
