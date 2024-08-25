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

  // Singleton instance of the DbService
  static final DbService _instance = DbService._internal();

  // Private constructor for the singleton pattern
  DbService._internal();

  // Factory constructor to return the singleton instance
  factory DbService() => _instance;

  // Cached list of notes for quicker access
  List<DatabaseNote> _notes = [];

  // Stream controller to broadcast the list of notes to listeners
  final _notesStreamController =
      StreamController<List<DatabaseNote>>.broadcast();

  // Getter to expose the stream of all notes
  Stream<List<DatabaseNote>> get allNotes => _notesStreamController.stream;

  Future<void> _cacheNotes() async {
    final allNotes = await getAllNotes();
    _notes = allNotes.toList();
    _notesStreamController.add(_notes);
  }

  Future<void> _ensureDbIsOpen() async {
    try {
      await open();
    } on DatabaseAlreadyOpenException {
      // empty
    }
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

  Future<DatabaseUser?> _getUserByEmail({required String email}) async {
    final results = await _queryTable(
      userTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );

    return results.isNotEmpty ? DatabaseUser.fromRow(results.first) : null;
  }

  Future<DatabaseUser> getUser({required String email}) async {
    await _ensureDbIsOpen();
    final user = await _getUserByEmail(email: email);
    return user ?? (throw CouldNotFindUserException());
  }

  Future<DatabaseUser> createUser({required String email}) async {
    await _ensureDbIsOpen();
    final existingUser = await _getUserByEmail(email: email);
    if (existingUser != null) throw UserAlreadyExistsException();

    final db = _getDatabaseOrThrow();
    final userId = await db.insert(userTable, {
      emailColumn: email.toLowerCase(),
    });

    return DatabaseUser(id: userId, email: email);
  }

  Future<void> deleteUser({required String email}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(
      userTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (deletedCount == 0) throw CouldNotDeleteUserException();
  }

  Future<DatabaseUser> getOrCreateUser({required String email}) async {
    try {
      return await getUser(email: email);
    } on CouldNotFindUserException {
      return await createUser(email: email);
    } catch (e) {
      // if an unexpected error occurs, instead of just catching it and doing nothing,
      // rethrow makes sure the error doesn't get ignored and can be handled somewhere else in the program
      // easier to debug
      rethrow;
    }
  }

  void _addNoteToCache({required DatabaseNote note}) {
    _notes.add(note);
    _notesStreamController.add(_notes);
  }

  void _updateNoteInCache({required DatabaseNote note}) {
    _notes.removeWhere((note) => note.id == note.id);
    _addNoteToCache(note: note);
  }

  void _removeNoteFromCache({required int noteId}) {
    _notes.removeWhere((note) => note.id == noteId);
    _notesStreamController.add(_notes);
  }

  void _removeAllNotesFromCache() {
    _notes.clear();
    _notesStreamController.add(_notes);
  }

  Future<DatabaseNote> getNote({required int noteId}) async {
    await _ensureDbIsOpen();
    final results = await _queryTable(
      noteTable,
      where: 'id = ?',
      whereArgs: [noteId],
      limit: 1,
    );

    if (results.isEmpty) {
      throw CouldNotFindNoteException();
    } else {
      final note = DatabaseNote.fromRow(results.first);
      _updateNoteInCache(note:
          note); // we need to update the cache bc the copy of the note in the cache may not be up-to-date
      return note;
    }
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    await _ensureDbIsOpen();
    final results = await _queryTable(noteTable, where: '1 = 1', whereArgs: []);
    return results.map(DatabaseNote.fromRow);
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    await _ensureDbIsOpen();
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
    await _ensureDbIsOpen();
    await getNote(noteId: note.id);

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
      final updatedNote = await getNote(noteId: note.id);
      _updateNoteInCache(note: updatedNote);
      return updatedNote;
    }
  }

  Future<void> deleteNote({required int noteId}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(
      noteTable,
      where: 'id = ?',
      whereArgs: [noteId],
    );

    if (deletedCount == 0) {
      throw CouldNotDeleteNoteException();
    } else {
      _removeNoteFromCache(noteId: noteId);
    }
  }

  Future<int> deleteAllNotes() async {
    await _ensureDbIsOpen();
    final db = _getDatabaseOrThrow();
    final numberOfDeletions = await db.delete(noteTable);

    _removeAllNotesFromCache();

    return numberOfDeletions;
  }
}
