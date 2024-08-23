import 'package:notes_app/services/auth/auth_user.dart';

// an authentication provider is a type of authentication method which users can use to perform
// authentication operations against, for example to sign-in, register or link an account

// any authentication provider (Apple, Facebook, Firebase, GitHub, Google, ...) will need
// to conform to the functionalities we have specified in this abstract class
abstract class AuthProvider {
  Future<void> initialize();

  AuthUser? get currentUser;

  Future<AuthUser> createUser(
      {required String email, required String password});

  Future<void> sendEmailVerification();

  Future<AuthUser> logIn({required String email, required String password});

  Future<void> logOut();
}
