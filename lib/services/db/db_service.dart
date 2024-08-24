import 'package:notes_app/models/note.dart';
import 'package:notes_app/models/user.dart';
import 'package:notes_app/services/db/db_exceptions.dart';
import 'package:notes_app/utilities/constants/db.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

class DbService {
  Database? _db;

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

    final userId = await _getDatabaseOrThrow().insert(userTable, {
      emailColumn: email.toLowerCase(),
    });

    return DatabaseUser(id: userId, email: email);
  }

  Future<void> deleteUser({required String email}) async {
    final deletedCount = await _getDatabaseOrThrow().delete(
      userTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (deletedCount == 0) throw CouldNotDeleteUserException();
  }

  Future<DatabaseNote> getNote({required int id}) async {
    final results = await _queryTable(
      noteTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return results.isNotEmpty ? DatabaseNote.fromRow(results.first) : (throw CouldNotFindNoteException());
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    final results = await _queryTable(noteTable, where: '1 = 1', whereArgs: []);
    return results.map(DatabaseNote.fromRow);
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    final dbUser = await getUser(email: owner.email);
    if (dbUser != owner) throw CouldNotFindUserException();

    final noteId = await _getDatabaseOrThrow().insert(noteTable, {
      userIdColumn: owner.id,
      textColumn: '',
      isSyncedWithCloudColumn: 1,
    });

    return DatabaseNote(
      id: noteId,
      userId: owner.id,
      text: '',
      isSyncedWithCloud: true,
    );
  }

  Future<void> updateNote({
    required DatabaseNote note,
    required String text,
  }) async {
    await getNote(id: note.id);

    final updatesCount = await _getDatabaseOrThrow().update(
      noteTable,
      {
        textColumn: text,
        isSyncedWithCloudColumn: 0,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );

    if (updatesCount == 0) throw CouldNotUpdateNoteException();
  }

  Future<void> deleteNote({required int id}) async {
    final deletedCount = await _getDatabaseOrThrow().delete(
      noteTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (deletedCount == 0) throw CouldNotDeleteNoteException();
  }

  Future<int> deleteAllNotes() async {
    return await _getDatabaseOrThrow().delete(noteTable);
  }
}
