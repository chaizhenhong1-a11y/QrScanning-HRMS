# Firebase Setup

The app is prepared for Firebase Core, Authentication, Cloud Firestore, Cloud Storage, and Cloud Messaging.

## App identifiers

Use these identifiers when registering platform apps in Firebase:

- Android application ID: `com.qrscanning.hrms`
- Apple bundle ID: `com.qrscanning.hrms`

Do not register Firebase against the previous `com.example.*` identifiers.

## Configure FlutterFire

From the project root:

```powershell
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Select the Firebase project that belongs to the HRMS platform and configure at least:

- Android
- iOS (when an Apple build environment is available)
- Web

The command replaces `lib/firebase_options.dart` with the real per-platform Firebase configuration. Re-run `flutterfire configure` whenever a Firebase product or supported platform is added.

## Firebase products to enable

In Firebase Console, enable these products before their feature migrations begin:

1. Authentication — Email/Password first.
2. Cloud Firestore — production mode; rules will be added with tenant isolation before business data is migrated.
3. Cloud Storage — employee documents, receipts, medical/supporting files and profile media.
4. Cloud Messaging — approval, memo and HR notifications in a later phase.

## Current migration state

This phase only establishes and verifies the Firebase connection layer. Existing local HRMS data remains on the current local repositories so Firebase configuration cannot break login, attendance, leave, or claims.

The next backend migration must introduce tenant-aware paths and security rules before any sensitive HR data is written to Firestore.
