import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/firebase/firebase_services.dart';
import '../../identity/application/identity_service.dart';
import '../../identity/domain/tenant_identity.dart';
import '../data/invitation_repository.dart';
import '../domain/employee_invitation.dart';
import '../domain/employee_profile.dart';

class InvitationService {
  InvitationService({InvitationRepository? repository, FirebaseAuth? auth})
    : _repository = repository ?? InvitationRepository(),
      _auth = auth ?? FirebaseServices.auth;

  final InvitationRepository _repository;
  final FirebaseAuth _auth;

  Future<EmployeeInvitation> issue(EmployeeProfile employee) async {
    return _repository.issueInvitation(employee: employee);
  }

  Future<TenantIdentity> activate({
    required String invitationCode,
    required String email,
    required String password,
  }) async {
    UserCredential? credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase did not return the created account.');
      }

      final identity = await _repository.redeemInvitation(
        invitationId: invitationCode.trim(),
      );

      await user.updateDisplayName(identity.displayName);

      final restored = await IdentityService().restoreIdentity();
      if (restored == null) {
        throw StateError('The employee account could not be activated.');
      }
      return restored;
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
}
