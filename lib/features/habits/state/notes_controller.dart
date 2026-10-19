import 'package:flutter/foundation.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/utils/cover_storage.dart';
import 'package:streak/features/habits/data/habit_note.dart';
import 'package:uuid/uuid.dart';

class NotesController extends ChangeNotifier {
  NotesController() {
    _notes = LocalStore.readNotes();
  }

  late List<HabitNote> _notes;
  Map<String, List<HabitNote>>? _days;
  Map<String, List<HabitNote>>? _habits;

  List<HabitNote> get all => List.unmodifiable(_notes);

  Map<String, List<HabitNote>> get _byDay => _days ??= _group(
        (note) => '${note.habitId}|${note.date}',
      );

  Map<String, List<HabitNote>> get _byHabit =>
      _habits ??= _group((note) => note.habitId);

  Map<String, List<HabitNote>> _group(String Function(HabitNote) key) {
    final groups = <String, List<HabitNote>>{};
    for (final note in _notes) {
      groups.putIfAbsent(key(note), () => []).add(note);
    }
    return groups;
  }

  void _changed() {
    _days = null;
    _habits = null;
    notifyListeners();
  }

  void reload() {
    _notes = LocalStore.readNotes();
    _changed();
  }

  static int _byTime(HabitNote a, HabitNote b) {
    final am = a.minutes ?? 24 * 60;
    final bm = b.minutes ?? 24 * 60;
    return am != bm ? am.compareTo(bm) : a.createdAt.compareTo(b.createdAt);
  }

  List<HabitNote> forDay(String habitId, String dayKey) =>
      [...?_byDay['$habitId|$dayKey']]..sort(_byTime);

  List<HabitNote> byDate({String? habitId}) {
    final list = habitId == null ? _notes : _byHabit[habitId] ?? const [];
    final days = {for (final note in list) note.date: parseDayKey(note.date)};
    return [...list]..sort((a, b) {
        final byDay = days[b.date]!.compareTo(days[a.date]!);
        return byDay != 0 ? byDay : _byTime(a, b);
      });
  }

  int countFor(String habitId, String dayKey) =>
      _byDay['$habitId|$dayKey']?.length ?? 0;

  Set<NoteType> typesFor(String habitId, String dayKey) => {
        for (final note in _byDay['$habitId|$dayKey'] ?? const <HabitNote>[])
          note.type,
      };

  bool hasAny(String habitId) => _byHabit.containsKey(habitId);

  List<HabitNote> photoNotes(String habitId) => [
        for (final note in _byHabit[habitId] ?? const <HabitNote>[])
          if (note.photos.isNotEmpty) note,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int photoCount(String habitId) => (_byHabit[habitId] ?? const <HabitNote>[])
      .fold(0, (sum, n) => sum + n.photos.length);

  Future<HabitNote> create({
    required String habitId,
    required String dayKey,
    required NoteType type,
    required String text,
    int? minutes,
    List<String> photos = const [],
  }) async {
    final note = HabitNote(
      id: const Uuid().v4(),
      habitId: habitId,
      date: dayKey,
      type: type,
      text: text.trim(),
      minutes: minutes,
      photos: photos,
      createdAt: DateTime.now(),
    );
    _notes.add(note);
    await LocalStore.writeNote(note);
    _changed();
    return note;
  }

  Future<void> update(HabitNote note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    final dropped =
        _notes[index].photos.where((p) => !note.photos.contains(p)).toList();
    _notes[index] = note;
    await LocalStore.writeNote(note);
    _changed();
    await CoverStorage.forgetAll(dropped);
  }

  Future<void> remove(String id) async {
    final photos = [
      for (final note in _notes.where((n) => n.id == id)) ...note.photos,
    ];
    _notes.removeWhere((n) => n.id == id);
    await LocalStore.removeNote(id);
    _changed();
    await CoverStorage.forgetAll(photos);
  }

  Future<void> removeForHabit(String habitId) async {
    final photos = [
      for (final note in _notes.where((n) => n.habitId == habitId))
        ...note.photos,
    ];
    _notes.removeWhere((n) => n.habitId == habitId);
    await LocalStore.removeNotesFor(habitId);
    _changed();
    await CoverStorage.forgetAll(photos);
  }
}
