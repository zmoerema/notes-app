import 'package:flutter/material.dart';
import 'package:notes_app/services/auth/auth_exceptions.dart';
import 'package:notes_app/services/auth/auth_service.dart';
import 'package:notes_app/utilities/constants/routes.dart';
import 'package:notes_app/utilities/dialogs/error_dialog.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: FutureBuilder(
        future: AuthService.firebase().initialize(),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              // if firebase is initialized successfully, show the registration form
              return Column(
                children: [
                  TextField(
                    controller: _email,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Enter your email here',
                    ),
                  ),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Enter your password here',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final email = _email.text;
                      final password = _password.text;

                      try {
                        await AuthService.firebase()
                            .createUser(email: email, password: password);
                        Navigator.of(context).pushNamedAndRemoveUntil(
                            VERIFY_EMAIL_ROUTE, (route) => false);
                      } on InvalidEmailAuthException {
                        await showErrorDialog(context, 'Invalid email');
                      } on WeakPasswordAuthException {
                        await showErrorDialog(context, 'Weak password');
                      } on EmailAlreadyInUseAuthException {
                        await showErrorDialog(
                            context, 'Email is already in use');
                      } on GenericAuthException {
                        await showErrorDialog(context, 'Failed to register');
                      }
                    },
                    child: const Text('Register'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        LOGIN_ROUTE,
                        (route) => false,
                      );
                    },
                    child: const Text('Already have an account ? Login here !'),
                  ),
                ],
              );
            default:
              // while firebase is still initializing, show a loading message
              return const Text('Loading...');
          }
        },
      ),
    );
  }
}
