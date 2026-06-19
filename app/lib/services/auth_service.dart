import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around Firebase Auth (email/password).
///
/// The signed-in user's `uid` is what the security rules scope /gardens to,
/// so a 1-user-1-garden setup can use the uid as the gardenId.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authState() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> register(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();
}
