import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String firebaseErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final message = error.message?.trim();
    switch (error.code) {
      case 'permission-denied':
        return message?.isNotEmpty == true
            ? message!
            : 'You do not have permission to perform this action.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      case 'not-found':
        return message?.isNotEmpty == true
            ? message!
            : 'The record was not found.';
      case 'already-exists':
        return message?.isNotEmpty == true
            ? message!
            : 'This record already exists.';
      case 'failed-precondition':
        return message?.isNotEmpty == true
            ? message!
            : 'This action cannot be completed in the current state.';
      case 'invalid-argument':
        return message?.isNotEmpty == true
            ? message!
            : 'Please check the information entered.';
      case 'resource-exhausted':
        return 'Too many requests. Please try again shortly.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The service is temporarily unavailable. Please try again.';
      default:
        return message?.isNotEmpty == true
            ? message!
            : 'Something went wrong. Please try again.';
    }
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Network connection failed. Please check your connection.';
      case 'requires-recent-login':
        return 'Please sign in again before performing this sensitive action.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  final value = error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
  return value.isEmpty ? 'Something went wrong. Please try again.' : value;
}
