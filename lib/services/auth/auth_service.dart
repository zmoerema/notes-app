import 'package:notes_app/services/auth/auth_provider.dart';
import 'package:notes_app/services/auth/auth_user.dart';
import 'package:notes_app/services/auth/firebase_auth_provider.dart';

// intermediary between the UI and the underlying data providers
// it handles business logic, data transformation, and coordination of various providers

// UI -> AuthService -> FirebaseAuthProvider -> Firebase server
//                   -> other providers -> ...

class AuthService implements AuthProvider {
  final AuthProvider provider;
  const AuthService(this.provider);

  factory AuthService.firebase() => AuthService(
      FirebaseAuthProvider()); // factory constructors are commonly used to enforce the singleton pattern, ensuring that only one instance of a class exists throughout the application

  @override
  Future<void> initialize() => provider.initialize();

  @override
  Future<AuthUser> createUser(
          {required String email, required String password}) =>
      provider.createUser(email: email, password: password);

  @override
  AuthUser? get currentUser => provider.currentUser;

  @override
  Future<AuthUser> logIn({required String email, required String password}) =>
      provider.logIn(email: email, password: password);

  @override
  Future<void> logOut() => provider.logOut();

  @override
  Future<void> sendEmailVerification() => provider.sendEmailVerification();
}
