import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';

@immutable // a class is immutable if all of the instance fields of the class, whether defined directly or inherited, are final
// abstraction of the Firebase user to the outside world (UI)
// UI -> AuthService -> AuthUser -> Firebase user
class AuthUser {
  final String? email;
  final bool isEmailVerified;
  const AuthUser({required this.email, required this.isEmailVerified});

  factory AuthUser.firebase(User user) => AuthUser(
    email: user.email,
    isEmailVerified: user.emailVerified,
  ); // factory constructors are commonly used to enforce the singleton pattern, ensuring that only one instance of a class exists throughout the application
}
