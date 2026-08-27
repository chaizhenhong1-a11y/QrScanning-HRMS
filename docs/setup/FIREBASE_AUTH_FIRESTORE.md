# Firebase Auth + Firestore Setup

Phase 005 uses Firebase Authentication and Cloud Firestore for the HRMS identity and tenant layer.

## Firebase Console

1. Open the `forum-d8b06` project.
2. Authentication → Sign-in method → enable **Email/Password**.
3. Firestore Database → create the database if it does not exist yet.
4. Choose the production rules option; deploy this project's `firestore.rules` immediately afterward.

## Deploy security rules

From the project root:

```powershell
firebase use forum-d8b06
firebase deploy --only firestore:rules
```

## Verify

Run:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter run -d edge
```

Use **Create a new company workspace** to create the first tenant owner. The onboarding flow writes:

- `companies/{companyId}`
- `users/{firebaseUid}`
- `companies/{companyId}/employees/{employeeId}`

The public registration flow intentionally creates only a `companyOwner`. Employee, Manager, and HR accounts must be provisioned by an authorized company administrator in a later employee-management phase.
