# Veyra HRMS — Employee invitation email setup

Phase 008 moves employee invitation issuance to a trusted Firebase Callable Cloud Function.

## 1. Requirements

Cloud Functions deployment requires a Firebase project on the Blaze plan.

Install function dependencies:

```powershell
cd functions
npm install
cd ..
```

Deploy the backend and Firestore rules:

```powershell
firebase use forum-d8b06
firebase deploy --only functions,firestore:rules
```

The callable function is deployed to `asia-southeast1`.

## 2. Install Firebase Trigger Email

In Firebase Console:

1. Open **Extensions**.
2. Install **Trigger Email** (`firestore-send-email`).
3. Set the email documents collection to:

```text
mail
```

4. Configure your SMTP provider and sender identity in the extension.
5. Finish the extension installation.

Veyra never stores SMTP passwords in Flutter. The Cloud Function only creates a mail job in the protected `mail` collection.

## 3. Test

1. Sign in as `companyOwner` or `hrAdmin`.
2. Open **Employees**.
3. Add an employee with a real work email.
4. Veyra calls `issueEmployeeInvitation`.
5. The function verifies the caller and employee against Firestore.
6. A 7-day invitation is generated.
7. A document is created under `mail`.
8. Trigger Email sends the invitation.
9. The employee opens Veyra → **Have an invitation? Activate account**.
10. The employee uses the emailed code, work email and a new password.

## Security boundary

Clients cannot create or revoke invitation documents directly. Firebase Admin SDK in Cloud Functions owns invitation issuance. The invited account can only accept the invitation matching its authenticated Firebase email.
