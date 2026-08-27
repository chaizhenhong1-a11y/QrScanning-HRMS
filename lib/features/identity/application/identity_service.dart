import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/firebase/firebase_services.dart';
import '../../../core/storage/session_store.dart';
import '../../../services/user_service.dart';
import '../data/identity_repository.dart';
import '../domain/tenant_identity.dart';

class IdentityService {
  IdentityService({IdentityRepository? repository})
    : _repository = repository ?? const IdentityRepository();

  final IdentityRepository _repository;

  FirebaseAuth get _auth => FirebaseServices.auth;

  Future<TenantIdentity?> restoreIdentity() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      await SessionStore.clearSession();
      return null;
    }

    final identity = await _repository.findByUid(firebaseUser.uid);
    if (identity == null || !identity.isActive) {
      await _auth.signOut();
      await SessionStore.clearSession();
      return null;
    }

    await _hydrateLegacySession(identity);
    return identity;
  }

  Future<TenantIdentity> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return a signed-in user.');
    }

    final identity = await _repository.findByUid(user.uid);
    if (identity == null) {
      await _auth.signOut();
      throw const IdentityProfileMissingException();
    }
    if (!identity.isActive) {
      await _auth.signOut();
      throw const IdentityDisabledException();
    }

    await _hydrateLegacySession(identity);
    return identity;
  }

  Future<TenantIdentity> registerCompanyOwner({
    required String email,
    required String password,
    required String companyName,
    required String employeeId,
    required String displayName,
  }) async {
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase did not return the created user.');
      }

      await user.updateDisplayName(displayName.trim());
      final identity = await _repository.createCompanyOwner(
        uid: user.uid,
        email: email,
        companyName: companyName,
        employeeId: employeeId,
        displayName: displayName,
      );
      await _hydrateLegacySession(identity);
      return identity;
    } catch (_) {
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          await _auth.signOut();
        }
      }
      rethrow;
    }
  }

  Future<TenantIdentity> updateMyDisplayName(String displayName) async {
    final normalizedName = displayName.trim();
    if (normalizedName.length < 2) {
      throw ArgumentError('Display name must contain at least 2 characters.');
    }
    if (normalizedName.length > 80) {
      throw ArgumentError('Display name cannot exceed 80 characters.');
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const IdentitySessionMissingException();
    }

    final identity = await _repository.findByUid(firebaseUser.uid);
    if (identity == null || !identity.isActive) {
      throw const IdentitySessionMissingException();
    }

    if (normalizedName == identity.displayName) {
      return identity;
    }

    final updated = await _repository.updateDisplayName(
      identity: identity,
      displayName: normalizedName,
    );

    try {
      await firebaseUser.updateDisplayName(normalizedName);
    } on FirebaseAuthException {
      // Firestore is the authoritative HRMS profile.
    }

    await _hydrateLegacySession(updated);
    return updated;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await SessionStore.clearSession();
  }

  Future<void> _hydrateLegacySession(TenantIdentity identity) async {
    UserService.upsertRemoteUser(
      id: identity.employeeId,
      name: identity.displayName,
      role: identity.legacyShellRole,
      department: identity.department,
    );
    await SessionStore.saveSession(
      userId: identity.employeeId,
      role: identity.legacyShellRole,
      companyId: identity.companyId,
      firebaseUid: identity.uid,
      hrmsRole: identity.role.value,
    );
  }
}

class IdentityProfileMissingException implements Exception {
  const IdentityProfileMissingException();

  @override
  String toString() =>
      'This account is authenticated but has no HRMS company profile.';
}

class IdentityDisabledException implements Exception {
  const IdentityDisabledException();

  @override
  String toString() => 'This HRMS account is inactive.';
}

class IdentitySessionMissingException implements Exception {
  const IdentitySessionMissingException();

  @override
  String toString() =>
      'Your HRMS session is unavailable. Please sign in again.';
}
