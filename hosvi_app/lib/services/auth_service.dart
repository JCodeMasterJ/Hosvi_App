import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> authState() => _auth.authStateChanges();

  Future<UserCredential> signInEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    return cred;
  }

  Future<UserCredential> signInAnon() => _auth.signInAnonymously();

  Future<void> signOut() => _auth.signOut();

  /// Lee el rol desde /users/{uid}  (fallback a /users/{email} si no existe uid)
  Future<String> getRoleFor(User user) async {
    // 1) por UID (recomendado)
    final byUid = await _db.collection('users').doc(user.uid).get();
    if (byUid.exists) {
      return (byUid.data()?['role'] as String?)?.toLowerCase() ?? 'user';
    }
    // 2) por email (por si ya creaste documentos con el correo como ID)
    final email = user.email?.toLowerCase();
    if (email != null) {
      final byEmail = await _db.collection('users').doc(email).get();
      if (byEmail.exists) {
        return (byEmail.data()?['role'] as String?)?.toLowerCase() ?? 'user';
      }
    }
    return 'user';
  }
}
