
# Veyra HRMS Release Readiness Checklist

Use this checklist before calling a build release-ready.

## 1. Static validation

- [ ] `flutter pub get`
- [ ] `dart format lib`
- [ ] `flutter analyze` returns **No issues found**
- [ ] Firebase Rules deploy without warnings
- [ ] Cloud Functions deploy completes successfully
- [ ] App starts on Edge
- [ ] App starts on Android device

## 2. Authentication and tenant isolation

### Company Owner
- [ ] Sign in successfully
- [ ] Dashboard loads without fallback error
- [ ] Can invite employees
- [ ] Can access company management features
- [ ] Cannot see data from another company

### HR Admin
- [ ] Can access HR administrative modules
- [ ] Can approve allowed workflows
- [ ] Can view Audit Log
- [ ] Cannot access another company

### Manager
- [ ] Can access management approvals intended for managers
- [ ] Cannot view confidential payroll totals
- [ ] Cannot view company Audit Log
- [ ] Cannot perform Owner / HR-only actions

### Employee
- [ ] Can access own Attendance
- [ ] Can submit Leave
- [ ] Can submit Claims
- [ ] Can view own Payslips
- [ ] Can view only own Documents
- [ ] Can view only own Assets
- [ ] Cannot approve own requests
- [ ] Cannot access HR administration

## 3. Attendance

- [ ] Clock in works
- [ ] Clock out works
- [ ] Duplicate clock action is handled safely
- [ ] QR attendance works when required
- [ ] Late / normal status is correct
- [ ] Team Attendance updates correctly
- [ ] Holiday / shift data does not break Attendance

## 4. Leave

- [ ] Employee can submit a valid request
- [ ] Manager / HR can approve
- [ ] Manager / HR can reject
- [ ] Self-approval is blocked
- [ ] Employee sees updated status
- [ ] Cancellation works when allowed
- [ ] Approved leave appears in relevant summaries

## 5. Claims

- [ ] Employee can submit a claim
- [ ] Receipt upload works
- [ ] Employee can see only own claims
- [ ] Manager / HR approval works
- [ ] Self-approval is blocked
- [ ] Approved claim can enter Payroll
- [ ] Paid status is reflected correctly

## 6. Payroll and Payslip

- [ ] Salary profile can be configured by authorized role
- [ ] Payroll draft generates
- [ ] Approved Claims are included correctly
- [ ] Unpaid Leave deduction is included correctly
- [ ] Finalization works once
- [ ] Finalized payroll cannot be regenerated accidentally
- [ ] Employee can see only own payslip
- [ ] Manager cannot see confidential payroll totals

## 7. Workforce Time

- [ ] Holiday creation works
- [ ] Shift assignment works
- [ ] Employee sees own shift data
- [ ] Overtime request works
- [ ] Overtime approval / rejection works
- [ ] Self-review of own OT is blocked

## 8. Employee Documents

- [ ] PDF upload works
- [ ] JPG / PNG upload works
- [ ] Unsupported files are rejected
- [ ] Employee sees only own documents
- [ ] HR can manage employee documents
- [ ] Expiry date is stored correctly
- [ ] Delete workflow works

## 9. Performance

- [ ] Review can be started
- [ ] KPI / Goal can be added
- [ ] Goal weight validation works
- [ ] Employee self-review works
- [ ] Manager review works
- [ ] Manager cannot finalize own review
- [ ] Completion notification is created

## 10. Onboarding / Offboarding

- [ ] HR can start onboarding
- [ ] Employee-completable tasks work
- [ ] HR-only tasks remain restricted
- [ ] Onboarding can complete only after checklist completion
- [ ] HR can start offboarding
- [ ] Offboarding is blocked while assets remain assigned
- [ ] Completing offboarding deactivates employee identity

## 11. Asset Management

- [ ] Asset can be registered
- [ ] Duplicate Asset Tag is rejected
- [ ] Asset can be assigned
- [ ] Employee sees assigned asset
- [ ] Asset can be returned
- [ ] Repair / Retired transitions work
- [ ] Assigned asset cannot be retired directly

## 12. Notifications

- [ ] Notification bell loads
- [ ] Unread badge is correct
- [ ] Notification Center opens
- [ ] Mark Read works
- [ ] Mark All Read works
- [ ] Notification failure does not break Dashboard

## 13. Audit Log

- [ ] Company Owner can view Audit Log
- [ ] HR Admin can view Audit Log
- [ ] Manager cannot view company Audit Log
- [ ] Employee cannot view company Audit Log
- [ ] Asset actions create audit entries
- [ ] Lifecycle completion creates audit entries
- [ ] Payroll finalization creates an audit entry
- [ ] Performance finalization creates an audit entry
- [ ] Overtime review creates an audit entry
- [ ] Employee Document changes create audit entries
- [ ] Filters by module / actor / date behave correctly
- [ ] Client cannot create, edit, or delete audit entries

## 14. Responsive UI

Test at minimum:

- [ ] Edge desktop 1920×1080
- [ ] Edge narrow window
- [ ] Android portrait
- [ ] Android landscape where relevant
- [ ] No RenderFlex overflow
- [ ] No clipped action buttons
- [ ] Dialogs remain usable on small screens
- [ ] Long employee names do not break layout

## 15. Final release gate

Release only when:

- [ ] No Flutter analyzer issues
- [ ] No Firebase Rules warnings
- [ ] No failed Cloud Function deployments
- [ ] No unresolved permission-denied errors in valid user flows
- [ ] Critical Owner / HR / Manager / Employee smoke tests pass
- [ ] Git working tree contains no unintended build/cache files
- [ ] Release commit is pushed to the intended GitHub repository
