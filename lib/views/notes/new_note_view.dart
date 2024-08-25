import 'package:flutter/material.dart';
import 'package:notes_app/models/note.dart';
import 'package:notes_app/services/auth/auth_service.dart';
import 'package:notes_app/services/db/db_service.dart';

class NewNoteView extends StatefulWidget {
  const NewNoteView({super.key});

  @override
  State<NewNoteView> createState() => _NewNoteViewState();
}

class _NewNoteViewState extends State<NewNoteView> {
  DatabaseNote? _note;
  late final DbService _db;
  late final TextEditingController _textController;

  @override
  void initState() {
    _db = DbService();
    _textController = TextEditingController();
    super.initState();
  }

  void _textControllerListener() async {
    // listens to changes in the text controller
    // updates the note in the database
    if (_note == null) return;

    await _db.updateNote(note: _note!, text: _textController.text);
  }

  void _setUpTextControllerListener() async {
    _textController.removeListener(
        _textControllerListener); // to avoid adding multiple listeners, which could lead to unwanted behavior
    _textController.addListener(
        _textControllerListener); // add _textControllerListener as the listener to the _textController
  }

  void _deleteNoteIfTextIsEmpty() {
    if (_textController.text.isEmpty && _note != null) {
      _db.deleteNote(noteId: _note!.id);
    }
  }

  void _saveNoteIfTextIsNotEmpty() async {
    if (_note != null && _textController.text.isNotEmpty) {
      _db.updateNote(note: _note!, text: _textController.text);
    }
  }

  @override
  void dispose() {
    _deleteNoteIfTextIsEmpty();
    _saveNoteIfTextIsNotEmpty();
    _textController.dispose();
    super.dispose();
  }

  Future<DatabaseNote> createNewNote() async {
    if (_note != null) {
      return _note!;
    }

    final currentUser = AuthService.firebase().currentUser!;
    final noteOwner = await _db.getUser(email: currentUser.email!);
    return await _db.createNote(owner: noteOwner);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('New Note'),
        ),
        body: FutureBuilder(
            future: createNewNote(),
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.done:
                  _note = snapshot.data as DatabaseNote;
                  _setUpTextControllerListener();
                  return TextField(
                    controller: _textController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Write your note here...',
                    ),
                  );
                default:
                  return const CircularProgressIndicator();
              }
            }));
  }
}
