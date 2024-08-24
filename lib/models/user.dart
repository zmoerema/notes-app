import 'package:flutter/foundation.dart';
import 'package:notes_app/utilities/constants/db.dart';

@immutable
class DatabaseUser {
  final int id;
  final String email;
  const DatabaseUser({
    required this.id,
    required this.email,
  });

  DatabaseUser.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  @override
  String toString() => 'Person, ID = $id, email = $email';

  @override
  bool operator ==(covariant DatabaseUser other) => id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

// WHAT IS COVARIANT
// In the superclass (Object), the == operator takes a parameter of type Object.
// By default, the overridden == operator in the DatabaseUser class would also need to accept any Object as its parameter.
// However, in your DatabaseUser class, you want to compare two DatabaseUser instances based on their id.
// If you don't use covariant, you'd have to accept any Object and then manually check if it is a DatabaseUser.

// EXAMPLE WITHOUT COVARIANT
// @override
// bool operator ==(Object other) {
//   if (other is DatabaseUser) {
//     return id == other.id;
//   }
//   return false;
// }