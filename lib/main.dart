import 'package:flutter/material.dart';
import 'package:notes_app/services/auth/auth_service.dart';
import 'package:notes_app/utilities/constants/routes.dart';
import 'package:notes_app/views/login_view.dart';
import 'package:notes_app/views/notes/new_note_view.dart';
import 'package:notes_app/views/notes/notes_view.dart';
import 'package:notes_app/views/register_view.dart';
import 'package:notes_app/views/verify_email_view.dart';
import 'dart:developer' as devtools show log;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
      routes: {
        LOGIN_ROUTE: (context) => const LoginView(),
        REGISTER_ROUTE: (context) => const RegisterView(),
        NOTES_ROUTE: (context) => const NotesView(),
        VERIFY_EMAIL_ROUTE: (context) => const VerifyEmailView(),
        NEW_NOTE_ROUTE: (context) => const NewNoteView(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: FutureBuilder(
        future: AuthService.firebase().initialize(),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              // if firebase is initialized successfully
              final user = AuthService.firebase().currentUser;

              if (user != null) {
                if (user.isEmailVerified) {
                  devtools.log('email already verified');
                  return const NotesView();
                } else {
                  devtools.log('email not verified');
                  return const VerifyEmailView();
                }
              } else {
                devtools.log('logged in');
                return const LoginView();
              }
            default:
              // while firebase is still initializing, show a loading message
              return const CircularProgressIndicator();
          }
        },
      ),
    );
  }
}
