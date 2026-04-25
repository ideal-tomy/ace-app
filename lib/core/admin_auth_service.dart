import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_config.dart';

class AdminAuthService {
  AdminAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    String? storeId,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storeId = storeId ?? AppConfig.storeId;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final String _storeId;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isCurrentUserAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (user.isAnonymous) return false;

    final token = await user.getIdTokenResult(true);
    final claimValue = token.claims?[AppConfig.adminRoleClaim];
    if (claimValue == true) return true;
    try {
      final adminDoc = await _firestore
          .collection('stores')
          .doc(_storeId)
          .collection('admins')
          .doc(user.uid)
          .get();
      return adminDoc.exists;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOutToAnonymous() async {
    await _auth.signOut();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
