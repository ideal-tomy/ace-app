import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_config.dart';

enum AppModuleRole {
  accounting('accounting'),
  expense('expense'),
  both('both');

  const AppModuleRole(this.value);
  final String value;
}

class AdminAuthService {
  AdminAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isCurrentUserAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<Set<AppModuleRole>> getCurrentUserModuleRoles() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return const <AppModuleRole>{};

    final token = await user.getIdTokenResult(true);
    final fromClaim = _parseRolesFromAny(
      token.claims?[AppConfig.moduleRolesClaim],
    );
    if (fromClaim.isNotEmpty) return fromClaim;

    final fromProfile = await _loadRolesFromProfile(uid: user.uid);
    if (fromProfile.isNotEmpty) return fromProfile;

    final isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) return const <AppModuleRole>{};
    return const {
      AppModuleRole.accounting,
      AppModuleRole.expense,
      AppModuleRole.both,
    };
  }

  Future<bool> canAccessAccounting() async {
    final roles = await getCurrentUserModuleRoles();
    return roles.contains(AppModuleRole.accounting) ||
        roles.contains(AppModuleRole.both);
  }

  Future<bool> canAccessExpense() async {
    final roles = await getCurrentUserModuleRoles();
    return roles.contains(AppModuleRole.expense) ||
        roles.contains(AppModuleRole.both);
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (user.isAnonymous) return false;

    final token = await user.getIdTokenResult(true);
    final claimValue = token.claims?[AppConfig.adminRoleClaim];
    if (claimValue == true) return true;
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return false;
    try {
      final adminDoc = await _firestore.collection('admins').doc(email).get();
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

  Future<Set<AppModuleRole>> _loadRolesFromProfile({
    required String uid,
  }) async {
    final profileRefs = <DocumentReference<Map<String, dynamic>>>[
      _firestore.collection('users').doc(uid),
      _firestore
          .collection('stores')
          .doc(AppConfig.storeId)
          .collection('users')
          .doc(uid),
    ];
    for (final ref in profileRefs) {
      try {
        final snapshot = await ref.get();
        if (!snapshot.exists) continue;
        final roles = _parseRolesFromAny(
          snapshot.data()?[AppConfig.moduleRolesField],
        );
        if (roles.isNotEmpty) return roles;
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') continue;
        rethrow;
      }
    }
    return const <AppModuleRole>{};
  }

  Set<AppModuleRole> _parseRolesFromAny(Object? raw) {
    final values = <String>[];
    if (raw is String) {
      values.add(raw);
    } else if (raw is Iterable) {
      for (final item in raw) {
        if (item is String) values.add(item);
      }
    }
    final roles = <AppModuleRole>{};
    for (final value in values) {
      for (final role in AppModuleRole.values) {
        if (role.value == value.trim()) {
          roles.add(role);
        }
      }
    }
    return roles;
  }
}
