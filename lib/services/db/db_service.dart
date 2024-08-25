import 'package:notes_app/models/note.dart';
import 'package:notes_app/models/user.dart';
import 'package:notes_app/services/db/db_exceptions.dart';
import 'package:notes_app/utilities/constants/db.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';
import 'dart:async';

class DbService {
  Database? _db;

  List<DatabaseNote> _notes = []; // cache notes for quicker access
  final _notesStreamController =
      StreamController<List<DatabaseNote>>.broadcast();

  Future<void> _cacheNotes() async {
    final allNotes = await getAllNotes();
    _notes = allNotes.toList();
    _notesStreamController.add(_notes);
  }

  Database _getDatabaseOrThrow() {
    if (_db == null) throw DatabaseNotOpenException();
    return _db!;
  }

  Future<void> open() async {
    if (_db != null) throw DatabaseAlreadyOpenException();

    try {
      final docsPath = await getApplicationDocumentsDirectory();
      final dbPath = join(docsPath.path, dbName);
      _db = await openDatabase(dbPath);

      await _createTables();
      await _cacheNotes();
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentsDirectoryException();
    }
  }

  Future<void> close() async {
    if (_db == null) throw DatabaseNotOpenException();

    await _db!.close();
    _db = null;
  }

  Future<void> _createTables() async {
    await Future.wait([
      _executeQuery(createUserTable),
      _executeQuery(createNoteTable),
    ]);
  }

  Future<void> _executeQuery(String query) async {
    await _getDatabaseOrThrow().execute(query);
  }

  Future<List<Map<String, dynamic>>> _queryTable(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
    int limit = 0,
  }) async {
    return await _getDatabaseOrThrow().query(
      table,
      limit: limit,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<DatabaseUser?> _getUserByEmail(String email) async {
    final results = await _queryTable(
      userTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );

    return results.isNotEmpty ? DatabaseUser.fromRow(results.first) : null;
  }

  Future<DatabaseUser> getUser({required String email}) async {
    final user = await _getUserByEmail(email);
    return user ?? (throw CouldNotFindUserException());
  }

  Future<DatabaseUser> createUser({required String email}) async {
    final existingUser = await _getUserByEmail(email);
    if (existingUser != null) throw UserAlreadyExistsException();

    final db = _getDatabaseOrThrow();
    final userId = await db.insert(userTable, {
      emailColumn: email.toLowerCase(),
    });

    return DatabaseUser(id: userId, email: email);
  }

  Future<void> deleteUser({required String email}) async {
    final db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(
      userTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (deletedCount == 0) throw CouldNotDeleteUserException();
  }

  void _addNoteToCache({required DatabaseNote note}) {
    _notes.add(note);
    _notesStreamController.add(_notes);
  }

  void _updateNoteInCache({required DatabaseNote note}) {
    _notes.removeWhere((note) => note.id == note.id);
    _addNoteToCache(note: note);
  }

  void _removeNoteFromCache({required int id}) {
    _notes.removeWhere((note) => note.id == id);
    _notesStreamController.add(_notes);
  }

  void _removeAllNotesFromCache() {
    _notes.clear();
    _notesStreamController.add(_notes);
  }

  Future<DatabaseNote> getNote({required int id}) async {
    final results = await _queryTable(
      noteTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) {
      throw CouldNotFindNoteException();
    } else {
      final note = DatabaseNote.fromRow(results.first);
      _updateNoteInCache(
          note:
              note); // we need to update the cache bc the copy of the note in the cache may not be up-to-date
      return note;
    }
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    final results = await _queryTable(noteTable, where: '1 = 1', whereArgs: []);
    return results.map(DatabaseNote.fromRow);
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    final dbUser = await getUser(email: owner.email);
    if (dbUser != owner) throw CouldNotFindUserException();

    final db = _getDatabaseOrThrow();
    final noteId = await db.insert(noteTable, {
      userIdColumn: owner.id,
      textColumn: '',
      isSyncedWithCloudColumn: 1,
    });

    final note = DatabaseNote(
      id: noteId,
      userId: owner.id,
      text: '',
      isSyncedWithCloud: true,
    );

    _addNoteToCache(note: note);

    return note;
  }

  Future<DatabaseNote> updateNote({
    required DatabaseNote note,
    required String text,
  }) async {
    await getNote(id: note.id);

    final db = _getDatabaseOrThrow();
    final updatesCount = await db.update(
      noteTable,
      {
        textColumn: text,
        isSyncedWithCloudColumn: 0,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );

    if (updatesCount == 0) {
      throw CouldNotUpdateNoteException();
    } else {
      final updatedNote = await getNote(id: note.id);
      _updateNoteInCache(note: updatedNote);
      return updatedNote;
    }
  }

  Future<void> deleteNote({required int id}) async {
    final db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(
      noteTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (deletedCount == 0) {
      throw CouldNotDeleteNoteException();
    } else {
      _removeNoteFromCache(id: id);
    }
  }

  Future<int> deleteAllNotes() async {
    final db = _getDatabaseOrThrow();
    final numberOfDeletions = await db.delete(noteTable);

    _removeAllNotesFromCache();

    return numberOfDeletions;
  }
}
