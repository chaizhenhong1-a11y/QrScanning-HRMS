# Changelog

All notable changes to the `qr_scanning` application are documented in this file.

## [3.5.4] - 2026-08-27

### Fixed
- Added the missing `_dateTime` formatter required by Flexible Work Approval History.
- Restored successful compilation of the Flexible Work history view.

### Changed
- Bumped the application version to `3.5.4+56`.

## [3.5.3] - 2026-08-27

### Completed
- Added Flexible Work Approval History.
- Added My Requests, Pending, and History views for approval-capable roles.
- History shows reviewed employee, decision, review note, reviewer, and review timestamp.

### Changed
- Bumped the application version to `3.5.3+55`.

## [3.5.2] - 2026-08-27

### Fixed
- Fixed Flexible Work `permission-denied` for ordinary employees by aligning Firestore queries with the existing authorization rules.
- My Requests now queries only documents where `uid` matches the authenticated Firebase user.
- Approvals retains the tenant-wide query only for roles that already have approval permission.
- Removed client-side whole-tenant reads for ordinary employees.

### Security
- Firestore Rules remain strict and unchanged; authorization was not weakened to fix the issue.
- Rules are no longer treated as a filter for employee request history.
- Ordinary employees cannot issue a query capable of returning another employee's flexible work request.

### Changed
- Bumped the application version to `3.5.2+54`.

## [3.5.1] - 2026-08-27

### Fixed
- Fixed all `curly_braces_in_flow_control_structures` analyzer findings introduced by the Flexible Work increment.
- Wrapped Flexible Work validation, dialog, picker, async-result, and error-handling branches in explicit blocks.
- Restored the zero-issue analyzer baseline without changing Flexible Work behavior.

### Changed
- Bumped the application version to `3.5.1+53`.

## [3.5.0] - 2026-08-27

### Completed
- Replaced the legacy local-only Flexible Work Arrangement demo with a tenant-scoped request and approval workflow.
- Employees can submit Work From Home, Hybrid, and Flexible Hours requests with date range, working hours, location, and reason.
- Employees can view their request history and withdraw pending requests.
- Manager, HR Admin, Company Owner, and existing management approvers can review pending requests.
- Reviewers cannot approve or reject their own flexible work requests.
- Added approval/rejection notes, reviewer identity, review timestamps, and withdrawn state.
- Added live Firestore-backed My Requests and Approvals views.

### Security
- Flexible work requests are isolated under `/companies/{companyId}/flexibleWorkRequests`.
- Employees can create and withdraw only requests tied to their own authenticated identity.
- Management roles can review other employees' pending requests but cannot self-approve.
- Client-side deletion is disabled.

### Changed
- Removed the hard-coded `Work From Home Today` switch and fake `WFH request submitted` behavior.
- Bumped the application version to `3.5.0+52`.

## [3.4.1] - 2026-08-27

### Fixed
- Restored the missing server-authoritative Expense Claims callable backend.
- Added `submitExpenseClaimV2`, `reviewExpenseClaimV2`, `cancelExpenseClaimV2`, and `markExpenseClaimPaidV2` as an isolated Firebase Functions codebase.
- Fixed the frontend/backend contract that previously caused `firebase_functions/internal` failures when submitting or managing claims.
- Claims submission now validates employee status, tenant identity, amount, category, expense date, receipt ownership, and field lengths server-side.
- Claim approval prevents self-review and supports Manager / HR Admin / Company Owner approval.
- Claim payment is restricted to Company Owner / HR Admin.
- Claim review and payment actions now publish employee notifications.
- Claim review and payment actions write immutable company audit records.
- Claims repository now targets the restored V2 callable contract so stale legacy deployments cannot intercept new claim actions.

### Architecture
- Added the `claims` Firebase Functions codebase so Claims can evolve independently without modifying or destabilizing the existing large default Functions entry point.

### Changed
- Bumped the application version to `3.4.1+51`.

## [3.4.0] - 2026-08-27

### Completed
- Replaced the legacy hard-coded Meeting Room Booking demo with a real tenant-scoped booking workflow.
- Company Owner and HR Admin can add, edit, enable, and disable meeting rooms.
- Meeting rooms now include name, location, capacity, equipment, and active availability status.
- Employees can book active rooms with a meeting purpose, start time, and end time.
- Added upcoming booking views, employee self-booking visibility, administrator company-wide booking visibility, and cancellation workflows.
- Added overlap checks before booking so conflicting room reservations are rejected.
- Completed the previously unfinished End Time picker.
- Preserved the existing `MeetingRoomScreen` entry point while moving implementation into a feature-first meeting rooms module.

### Security
- Meeting rooms and bookings are isolated under each `/companies/{companyId}` tenant.
- Only Company Owner and HR Admin can manage room inventory.
- Employees can create bookings only for their own authenticated employee identity.
- Employees can read and cancel only their own bookings; Company Owner and HR Admin can view and cancel company bookings.
- Firestore Rules validate room metadata, booking ownership, time ranges, purpose length, and cancellation-only client updates.

### Changed
- Removed the runtime dependency on the legacy hard-coded `RoomService` room and booking samples.
- Bumped the application version to `3.4.0+50`.

## [3.3.0] - 2026-08-27

### Completed
- Replaced the legacy hard-coded Company Policy page with a real tenant-scoped Veyra Company Policy Center.
- Company Owner and HR Admin can publish, edit, activate, deactivate, and delete company policies.
- Employees can read active company policies from their own tenant.
- Added policy categories for Attendance, Leave, Dress Code, Flexible Work, Benefits, Code of Conduct, and General.
- Added live Firestore updates, category filtering, empty/error states, validation, author metadata, and update timestamps.
- Preserved the existing `CompanyPolicyScreen` entry point as a compatibility adapter while moving the implementation into a feature-first module.

### Security
- Company policies are isolated under `/companies/{companyId}/companyPolicies`.
- Inactive policies are visible only to Company Owner and HR Admin.
- Policy mutations are restricted to Company Owner and HR Admin.
- Firestore Rules validate policy fields, lengths, category values, immutable creator metadata, and tenant membership.

### Changed
- Removed the runtime hard-coded `9am - 6pm`, `Smart casual`, and placeholder Leave Policy content.
- Bumped the application version to `3.3.0+49`.

## [3.2.1] - 2026-08-27

### Fixed
- Fixed the Attendance Policy build failure by providing the required `minute` values to both default `TimeOfDay` instances.
- Fixed the async navigation context lint in the unsaved-changes back-navigation guard.
- Restored the zero-error analyzer baseline for the Attendance Policy hardening increment.

### Changed
- Bumped the application version to `3.2.1+48`.

## [3.2.0] - 2026-08-27

### Completed
- Replaced the legacy hard-coded HR Memos sample list with a real tenant-scoped Firestore company announcement workflow.
- Employees can now read company HR announcements published inside their own Veyra workspace.
- Company Owner and HR Admin can publish, edit, and remove HR memos.
- Added memo title, body, author, publish timestamp, and update timestamp metadata.
- Added a professional empty state, live updates, refresh support, loading states, validation, and destructive-action confirmation.
- Kept the existing `HrMemosScreen` entry point as a compatibility adapter while moving the implementation into a feature-first HR Memos module.

### Security
- HR Memos are isolated under `/companies/{companyId}/hrMemos`.
- Active employees can read only memos from their own tenant.
- Only Company Owner and HR Admin can create, update, or delete company HR memos.
- Firestore Rules validate memo shape, title/body length, author UID, and immutable creator metadata.

### Changed
- Removed the runtime dependency on the legacy hard-coded `MemoService` sample data.
- Bumped the application version to `3.2.0+47`.

## [3.1.8] - 2026-08-27

### Hardened
- Hardened the existing Attendance Policy screen against backend and session failures.
- Added a recoverable load-error state instead of leaving the page on a permanent loading spinner when attendance settings cannot be fetched.
- Reused the shared Firebase/backend error mapper for settings load and save failures.
- Added duplicate-save protection and disabled policy controls while a save is in progress.
- Added a visible unsaved-changes guard before leaving Attendance Policy.
- Added a no-change fast path so unchanged policy data is not sent to the backend.
- Added validation for work hours and time-zone selection before saving.

### Changed
- Attendance Policy now stays on-screen after a successful save so HR admins can verify the persisted values instead of being forced back immediately.
- Bumped the application version to `3.1.8+46`.

## [3.1.7] - 2026-08-27

### Completed
- Completed the existing Notification Center navigation flow.
- Added a Notification Center entry to Profile so the existing Firestore notification inbox is reachable from the signed-in application.
- Leave notifications now open the real Leave workflow.
- Claim notifications now open the real Claims workflow.
- Payslip notifications now open the real Payslip workflow.
- Notifications with unknown or future target types fall back safely without breaking navigation.

### Hardened
- Added duplicate-action protection for Mark All Read.
- Added visible backend error feedback for Mark All Read and single-notification read actions.
- Added a progress state while marking all notifications as read.
- Preserved the notification as usable even when marking it read fails.

### Changed
- Bumped the application version to `3.1.7+45`.

## [3.1.6] - 2026-08-27

### Fixed
- Replaced the broken Profile `'/history'` named-route navigation with the real Attendance History screen.
- Replaced the broken Profile `'/settings'` named-route navigation with a real Veyra Account Settings screen.
- Removed two runtime navigation paths that referenced routes not registered by the current application router.

### Completed
- Completed the existing Settings entry with authenticated account details, role visibility, tenant/employee identifiers, and password-reset email access.
- Password-reset requests from Settings reuse Firebase Authentication and the configured custom SMTP delivery path.
- Added loading, success, throttling, and backend error states for account-settings password reset.

### Changed
- Bumped the application version to `3.1.6+44`.

## [3.1.5] - 2026-08-27

### Fixed
- Replaced the legacy local-only Edit Profile save path with the authenticated multi-tenant Firebase identity flow.
- Profile now reloads the signed-in tenant identity from Firestore instead of trusting the temporary in-memory `UserService` cache.
- Department is now read-only in self-service Profile editing because organizational assignment is HR-managed data.
- Employee Profile updates synchronize `displayName` across the tenant user profile and employee directory record.
- Added a tightly-scoped Firestore self-update rule allowing employees to update only their own `displayName` and `updatedAt` fields.
- Corrected Profile feature visibility so employee self-service modules are no longer hidden behind the legacy `boss` compatibility role.
- Restricted Audit Log and Work Time Settings visibility to Company Owner / HR Admin while keeping Reports available to management roles.
- Updated the About dialog branding from the legacy Company Attendance name to Veyra HRMS.

### Hardened
- Added profile-name validation, duplicate-save protection, backend error feedback, and safe refresh failure handling.
- Firebase Auth display name is refreshed after the authoritative HRMS profile update so authentication metadata remains aligned.

### Changed
- Bumped the application version to `3.1.5+43`.

## [3.1.4] - 2026-08-27

### Hardened
- Completed the existing Forgot Password workflow with form validation, normalized work-email input, resend support, and a 30-second resend cooldown.
- Added a safe change-email path after a reset request without requiring navigation back to Sign In.
- Password-reset success messaging no longer reveals whether an employee account exists for the entered email.
- Reused the shared Firebase error mapper for password-reset failures instead of maintaining screen-specific Firebase error strings.
- Expanded shared Firebase Auth error mapping for invalid email, disabled account, throttling, unavailable auth method, invalid credentials, duplicate email, and weak-password failures.
- Added unexpected-error handling so password-reset failures cannot leave the action permanently loading.

### Changed
- Bumped the application version to `3.1.4+42`.

## [3.1.3] - 2026-08-27

### Fixed
- Removed the unused Firestore Rules `invitationPath` helper.
- Replaced the invalid `canManageCompany()` Rules reference in Employee Documents with the existing company-role authorization expression.
- Preserved the same Owner / HR Admin and employee-self document read policy while eliminating the Rules compiler warnings.

### Release readiness
- Added a structured Owner / HR Admin / Manager / Employee release verification checklist.
- Added smoke-test coverage for Attendance, Leave, Claims, Payroll, Workforce Time, Documents, Performance, Lifecycle, Assets, Notifications, Audit Log, responsive UI, and final release gates.

### Changed
- Bumped the application version to `3.1.3+41`.

## [3.1.2] - 2026-08-27

### Hardened
- Added a shared Firebase/Auth error-to-message mapper for consistent user-facing failures.
- Audit Log now displays actionable backend error messages instead of a generic failure.
- Expanded immutable server-side audit coverage across additional administrative workflows.
- Added audit hooks for: updateAttendanceSettings, reviewOvertimeRequest, registerEmployeeDocument, deleteEmployeeDocument.
- Continued the Phase 022 policy of hardening existing modules instead of adding new product modules.

### Changed
- Bumped the application version to `3.1.2+40`.

## [3.1.1] - 2026-08-27

### Hardened
- Added duplicate-refresh protection to the Audit Log screen.
- Added reusable `AsyncActionGuard` for sensitive UI actions to prevent accidental double submission.
- Added server-side allow-list validation for Audit Log module filters.
- Bounded Audit Log action and actor filter input lengths before querying.
- Preserved server-authoritative audit access and immutable client rules.

### Changed
- Bumped the application version to `3.1.1+39`.

## [3.1.0] - 2026-08-27

### Added
- Added immutable company Audit Log / Admin Activity History.
- Added Company Owner / HR Admin Audit Log page.
- Added filters for module, action, actor employee ID, and date range.
- Audit records capture actor UID, actor employee ID, actor name, role, module, action, target type, target ID, summary, result, metadata, and server timestamp.
- Added server-authoritative `getAuditLog` Cloud Function.
- Added reusable backend `writeAuditLog` helper for sensitive operations.
- Added auditing for company asset creation, assignment, return, and status changes.
- Added auditing for onboarding/offboarding start and lifecycle completion.
- Added auditing for performance-review finalization.
- Added auditing for payroll finalization.
- Added auditing hooks for Claim and Leave approval workflows where the current function implementation exposes the standard decision return.
- Added Profile entry for Audit Log.

### Security
- Audit records cannot be created, edited, or deleted directly by clients.
- Company audit history is accessible only through Cloud Functions.
- Only Company Owner and HR Admin can query company audit history.
- Audit timestamps are written by the server.

### Architecture
- Critical administrative actions can now call a shared audit writer, allowing future modules to be covered without duplicating persistence logic.

### Changed
- Bumped the application version to `3.1.0+38`.


## [3.0.0] - 2026-08-27

### Added
- Added professional Company Asset Management.
- Added asset registration with Asset ID / Tag, category, serial number, purchase date, warranty expiry, and notes.
- Added Available, Assigned, Repair, and Retired asset states.
- Added employee assignment and return workflows.
- Employees can view assets currently assigned to them through My Assets.
- Company Owner / HR Admin can view and manage the company asset inventory.
- Added company asset assignment notifications.
- Added Profile entry for Asset Management.
- Added server-authoritative asset Cloud Functions.

### Integrated
- Offboarding now checks the live asset inventory before completion.
- An employee with any assigned company asset cannot complete offboarding until all assets have been returned.
- Returned assets become available for reassignment.

### Security
- Asset inventory is company-scoped.
- Employees can retrieve only assets assigned to themselves.
- Asset registration, assignment, return, repair, and retirement require Company Owner / HR Admin permission.
- Direct Firestore access to asset inventory is disabled; operations are validated through Cloud Functions.

### Changed
- Bumped the application version to `3.0.0+37`.


## [2.9.0] - 2026-08-27

### Added
- Added Employee Onboarding & Offboarding lifecycle module.
- Added HR-managed onboarding workflows with start date and optional probation end date.
- Added onboarding checklist for employee profile, required documents, policy acknowledgement, HR assignment, access provisioning, and orientation.
- Added offboarding workflow with last working day, exit reason, handover, asset return, finance clearance, exit acknowledgement, and access revocation.
- Employees can complete only checklist items explicitly assigned to the employee.
- Company Owner / HR Admin can manage all checklist items and close completed lifecycle workflows.
- Added lifecycle progress indicators and active/completed workflow status.
- Added Notification Center events when onboarding/offboarding starts and completes.
- Completing onboarding records employment start/probation data on the employee profile.
- Completing offboarding marks the employee and identity inactive after all exit tasks are completed.
- Added Profile entry for Onboarding & Offboarding.
- Added server-authoritative lifecycle Cloud Functions.

### Security
- Employees can see only their own lifecycle workflows.
- Company Owner / HR Admin can manage lifecycle workflows only inside their company.
- Company Owner / HR Admin cannot initiate offboarding for their own account through this workflow.
- Firestore lifecycle documents cannot be directly read or mutated by clients.

### Changed
- Bumped the application version to `2.9.0+36`.


## [2.8.0] - 2026-08-27

### Added
- Added Performance Review + KPI / Goals module.
- Employees can start an annual review, create KPI / Goals, assign weights, track progress, submit a self-rating, and add self-review comments.
- Manager / HR / Owner can view team reviews and finalize employee performance with a manager rating and review comments.
- Added Goal Setting, Self Review, Manager Review, and Completed workflow states.
- Added validation for KPI weight, progress percentages, rating range, and total goal weight.
- Added management workflow for starting an employee review by Employee ID.
- Added Performance & KPI entry in Profile.
- Added Notification Center events when an employee submits a self review and when management finalizes the review.
- Added server-authoritative `getPerformanceOverview`, `ensurePerformanceReview`, `upsertPerformanceGoal`, `submitPerformanceSelfReview`, and `finalizePerformanceReview` Cloud Functions.

### Security
- Employees can edit and submit only their own performance review.
- Manager / HR / Owner can review other employees but cannot finalize their own performance review.
- Performance Review Firestore documents cannot be directly read or mutated by the client; all access is scoped and validated through Cloud Functions.

### Changed
- Bumped the application version to `2.8.0+35`.


## [2.7.0] - 2026-08-27

### Added
- Added Employee Documents / HR File Vault with PDF and image uploads.
- Added IC / Passport, Offer Letter, Contract, Certificate, Medical, and Other document categories.
- Added employee self-document access and Company Owner / HR company-wide document management.
- Added optional document expiry dates and document notes.
- Added secure Firebase Storage paths scoped by company and employee.
- Added Firestore document metadata with uploader, employee, content type, size, and expiry information.
- Added secure-link copy action and document removal workflow.
- Added Notification Center message when a document with an expiry date is registered.
- Added Profile entry for Employee Documents.
- Added server-authoritative `registerEmployeeDocument` and `deleteEmployeeDocument` Cloud Functions.

### Security
- Employees can access only their own document records and Storage path.
- Company Owner and HR Admin can manage employee documents within their own company only.
- Firestore document metadata cannot be directly mutated by clients.
- Uploads are limited to PDF/JPEG/PNG and 15 MB.
- Storage paths are validated again by Cloud Functions before metadata registration.

### Changed
- Added `file_picker` for cross-platform document selection.
- Bumped the application version to `2.7.0+34`.


## [2.6.0] - 2026-08-27

### Added
- Added Company Holiday management for Company Owner and HR Admin.
- Added employee shift assignments with date, shift name, start time, and end time.
- Added employee Overtime requests with date, duration, reason, Pending / Approved / Rejected workflow.
- Added Manager / HR / Owner overtime approval while preventing self-approval.
- Added Holiday, Shift & Overtime management page with month filtering and Veyra Design System styling.
- Added Profile entry for the new workforce-time module.
- Added server-authoritative `getWorkforceTimeOverview`, `upsertCompanyHoliday`, `assignEmployeeShift`, `submitOvertimeRequest`, and `reviewOvertimeRequest` Cloud Functions.

### Security
- Holiday and shift mutations are Cloud Function only.
- Employees see only their own shift and overtime records; management roles can view company workforce-time records.
- Employees cannot approve or reject their own overtime request.
- Company Holiday creation is limited to Company Owner and HR Admin.

### Changed
- Bumped the application version to `2.6.0+33`.


## [2.5.0] - 2026-08-27

### Added
- Added Professional Reports & Analytics for Company Owner, HR Admin, and Manager.
- Added month-based Workforce, Attendance, Leave, and Expense Claims analytics.
- Added active headcount, employees present, attendance records, completion count, late count, and early-leave count.
- Added approved leave request/day totals and pending leave workload.
- Added claim volume, Pending / Approved / Paid counts, and monthly claim amount.
- Added confidential Payroll summary for Company Owner and HR Admin only.
- Added Copy Report action for quick sharing of the monthly HR summary.
- Added Reports & Analytics entry to the management Profile menu.
- Added server-authoritative `getMonthlyHrReport` Cloud Function.

### Privacy
- Managers can access operational HR analytics but do not receive payroll totals.
- Payroll status, payroll employee count, and total net pay are returned only to Company Owner and HR Admin.

### Architecture
- Added independent Reports domain, repository, application service, and presentation page.
- Aggregation is performed server-side rather than trusting client-calculated management totals.

### Changed
- Bumped the application version to `2.5.0+32`.


## [2.4.0] - 2026-08-27

### Added
- Added the Veyra Notification Center with real-time Firestore notifications, unread indicators, read state, and Mark All Read.
- Added a Dashboard notification bell with a live unread badge.
- Added server-authoritative per-user notification storage under each company tenant.
- Added notification target metadata for Leave, Claims, Payslips, invitations, and future deep-link routing.
- Payroll finalization now publishes a Payslip notification to each employee whose identity can be resolved.

### Security
- Clients cannot create or delete HRMS notifications.
- Employees can read only the notification inbox addressed to their own Firebase UID.
- Client updates are restricted to `isRead` and `readAt`.
- Notification data remains isolated under the authenticated company tenant.

### Architecture
- Added independent notification domain, repository, application service, presentation page, and reusable notification-bell widget.
- Notification Center is real-time and does not block Dashboard startup if the inbox is temporarily unavailable.

### Changed
- Bumped the application version to `2.4.0+31`.


## [2.3.2] - 2026-08-26

### Fixed
- Fixed Flutter's `ListTile background color or ink splashes may be invisible` assertion in Profile by making Material the immediate ListTile ink surface.
- Restored secure Firestore read access for the professional Claims collection.
- Employee claim reads remain limited to their own `employeeId`; management roles retain tenant-scoped company access.
- Bounded My Claims reads to 100 records.

### Changed
- Bumped the application version to `2.3.2+30`.


## [2.3.1] - 2026-08-26

### Fixed
- Prevented the whole Dashboard from failing when Attendance, Leave, or Claims temporarily fails to load.
- Attendance settings now fall back to safe defaults.
- Attendance history, today's attendance, approved leave, and claim summary now fail independently.
- Added terminal debug logging for optional Dashboard modules so permission, deployment, or network errors are visible.
- Added debug logging for the remaining core session/identity failure path.

### Architecture
- Only the authenticated HRMS session and local employee identity are hard requirements for rendering Home.
- Feature modules no longer take down the entire Home screen when one backend dependency is unavailable.

### Changed
- Bumped the application version to `2.3.1+29`.


## [2.3.0] - 2026-08-26

### Added
- Added Firestore-backed salary profiles for Basic Salary, fixed allowance, fixed deduction, employee EPF, SOCSO and EIS amounts.
- Added monthly payroll draft generation for active employees with configured salary profiles.
- Added approved expense-claim reimbursements to payroll calculations.
- Added approved Unpaid Leave deductions with month overlap handling.
- Added Draft and Finalized payroll states and immutable finalized payroll protection.
- Added employee Firestore payslips and a Veyra-styled Payslip screen.
- Added Company Owner / HR Payroll Administration with month selection, draft generation and finalization.
- Added server-authoritative `setSalaryProfile`, `generatePayrollDraft`, and `finalizePayroll` Cloud Functions.
- Finalizing payroll marks included approved expense claims as Paid with a payroll payment reference.

### Payroll foundation
- Payroll amounts are stored in MYR.
- EPF, SOCSO and EIS are explicit salary-profile amounts in this foundation; statutory-rate automation is intentionally not guessed.
- Unpaid Leave currently uses an explicit 26-day salary divisor stored on each generated payslip so a later configurable payroll-policy module can replace it safely.

### Security
- Employees can read only their own payslips and salary profile.
- Company Owner and HR Admin can manage payroll and read company payroll data.
- Payroll and salary mutations are blocked from direct client writes and must pass Cloud Functions.

### Changed
- Replaced the legacy local mock Payslip screen with the Firestore payroll foundation.
- Bumped the application version to `2.3.0+28`.


## [2.1.1] - 2026-08-26

### Fixed
- Restored the Veyra Auth Shell color aliases expected by the existing Login/Register UI: `navy`, `blue`, `sky`, and `blueDark`.
- Mapped Auth Shell aliases back to the canonical Veyra Design System so authentication and signed-in screens share one source of truth.
- Fixed the resulting `invalid_constant`, `non_constant_list_element`, and undefined getter analyzer errors.

### Changed
- Bumped the application version to `2.1.1+25`.


## [2.1.0] - 2026-08-26

### Added
- Established the Veyra in-app design foundation from the existing Login screen palette and visual language.
- Added reusable canonical page and brand gradients plus shared surface styling.

### Changed
- Unified the authenticated App Shell and Dashboard with the Login screen's light blue background, cyan-blue brand gradient, white elevated surfaces, typography and navigation treatment.
- Updated the global application theme so new authenticated surfaces inherit the Veyra visual language instead of the previous generic Material styling.
- Approvals now exclude the current employee's own pending leave requests from the UI while the Cloud Function self-approval protection remains authoritative.
- Bumped the application version to `2.1.0+24`.

## [2.0.1] - 2026-08-26

### Fixed
- Fixed Leave Approvals appearing to do nothing after Approve/Reject.
- Leave Approvals now remain subscribed to the live Firestore pending-request stream instead of converting the stream into a stale one-shot Future.
- Approved/rejected requests disappear from the pending list immediately after the backend transaction commits.
- Added visible review progress, success feedback, backend error feedback, and duplicate-click protection.
- Pull-to-refresh now re-establishes the leave approval stream safely.

### Security / Rules
- Removed the obsolete `isValidInviteIdentity` Firestore rules helper left behind after employee invitation redemption moved to Cloud Functions.
- This removes the related Firestore rules deployment warnings without changing the current server-authoritative activation flow.

### Changed
- Bumped the application version to `2.0.1+23`.


## [2.0.0] - 2026-08-26

### Added
- Added production-style Firestore Leave Management scoped to each company workspace.
- Added configurable leave types with annual quota, paid/unpaid status, and optional required supporting attachment.
- Added annual employee Leave Balance with `used`, `reserved`, and remaining entitlement tracking.
- Added Annual, Sick, Emergency, Unpaid, and company-configurable leave policy support.
- Added Full Day, Half Day Morning, and Half Day Afternoon requests.
- Added working-day calculation that excludes Saturdays and Sundays.
- Added Firebase Storage supporting-image upload with tenant/employee security rules and a 10 MB image limit.
- Added backend overlap detection to prevent conflicting pending/approved requests.
- Added employee cancellation for pending requests.
- Added Leave Policy administration for Company Owner and HR Admin.
- Added approved-leave integration with Dashboard and Attendance.
- Team Attendance now surfaces employees on approved leave even when they have no attendance record.

### Workflow
- Submitting quota-based leave reserves the requested entitlement immediately.
- Approval atomically moves reserved entitlement into used entitlement.
- Rejection and employee cancellation atomically release reserved entitlement.
- Leave review records reviewer identity, review timestamp, and optional review note.

### Security
- Leave submission, review, cancellation, policy changes, and balance mutations are server-authoritative Cloud Functions.
- Employees can read only their own leave requests/balance; Manager, HR Admin, and Company Owner can review company leave data.
- Client applications cannot directly write Leave Requests or Leave Balances.
- Storage uploads are isolated by authenticated company and employee identity.
- Attendance Cloud Function blocks Clock In/Out when an approved leave covers the current company-local date.

### Changed
- Replaced SharedPreferences leave requests with Firestore multi-tenant data.
- Existing Leave and Approvals navigation now uses the professional Leave service without changing the public page entry points.
- Bumped the application version to `2.0.0+22`.


## [1.9.3] - 2026-08-26

### Fixed
- Fixed the Attendance page runtime error where a `setState` callback returned a `Future`.
- Fixed the same asynchronous `setState` pattern in Attendance History refresh handling.
- Attendance refresh now schedules the new Future synchronously and awaits it outside `setState`, as required by Flutter.

### Changed
- Bumped the application version to `1.9.3+21`.


## [1.9.2] - 2026-08-26

### Fixed
- Fixed the dashboard failing to load after Phase 009 when Firestore attendance queries required composite indexes.
- Employee attendance history and today's attendance now use index-free tenant-scoped queries and perform date sorting in the application layer.
- Team Attendance no longer requires a `dateKey + employeeName` composite Firestore index.

### Changed
- Kept attendance reads compatible with the existing Firestore rules and multi-tenant company isolation without requiring manual index creation.
- Bumped the application version to `1.9.2+20`.


## [1.9.1] - 2026-08-26

### Fixed
- Fixed employee invitation activation on Flutter Web/Edge where the client-side Firestore transaction could surface as an opaque converted-Future Dart/JavaScript exception.
- Added readable Firebase Functions activation errors for invalid, expired, replaced, mismatched-email, inactive, or already-used invitations.

### Security
- Moved employee invitation redemption to the trusted `redeemEmployeeInvitation` Cloud Function.
- Company ID, employee ID, work email, invitation status, expiration, employee status, role, and current invitation ID are validated by the backend before an account can be linked.
- Firebase UID binding, HRMS user creation, employee activation, and invitation acceptance now commit atomically in one Admin SDK transaction.
- Firestore client rules no longer allow employee activation to create HRMS identities or mutate invitation acceptance directly.

### Changed
- Flutter now only creates the Firebase Auth credential and requests backend invitation redemption; HRMS tenant identity mutation is server-authoritative.
- Bumped the application version to `1.9.1+19`.


## [1.9.0] - 2026-08-26

### Added
- Added Firestore-backed multi-tenant attendance records under each company workspace.
- Added server-authoritative Clock In / Clock Out through Cloud Functions using Firebase authenticated identity and server time.
- Added configurable attendance policy: work start, work end, late grace period, company time zone, and optional mandatory QR mode.
- Added employee Attendance hub with direct mobile clocking, secure QR scanning, today's status, worked duration, and Firestore attendance history.
- Added HR/manager Team Attendance view with date filtering and daily present/late/completed summaries.
- Added secure company attendance QR tokens issued by Cloud Functions and valid for 90 seconds.

### Security
- Attendance writes are denied to Flutter clients and are performed only by trusted Cloud Functions.
- Secure QR tokens are random server-issued values; only a SHA-256 hash is persisted in Firestore.
- Clock In/Out uses server timestamps and company time-zone rules, preventing device clock manipulation.
- Employee attendance reads are restricted to the employee's own records; company owner, HR admin, and managers can review team attendance.
- Attendance QR backing documents are inaccessible to clients.

### Changed
- Dashboard attendance and history now use Firestore instead of SharedPreferences attendance records.
- Legacy `AttendanceService`, `HistoryScreen`, and `WorkTimeSettingsScreen` now act as compatibility adapters over the professional attendance feature.
- Employee bottom navigation now opens the Attendance hub; administrators/managers keep the secure company Code tab.
- Bumped the application version to `1.9.0+18`.


## [1.8.2] - 2026-08-25

### Fixed
- Replaced the unreliable Trigger Email Extension delivery path with direct SMTP delivery inside the secured `issueEmployeeInvitation` Cloud Function.
- Added Nodemailer Gmail SMTPS delivery using a dedicated Cloud Functions Secret Manager secret.
- Invitation documents now record backend email delivery status, message ID, timestamps, or delivery error details.

### Security
- SMTP credentials are read only by the deployed Cloud Function through `VEYRA_SMTP_PASSWORD`.
- No Gmail password or App Password is stored in Flutter, Firestore, or source code.

### Changed
- Employee invitation creation and email delivery now happen in one trusted backend workflow.
- The old `mail` queue is no longer required for Veyra employee invitation delivery.
- Bumped the application version to `1.8.2+17`.


## [1.8.0] - 2026-08-25

### Added
- Added a Node.js 22 Firebase Cloud Functions backend for trusted employee invitation issuance.
- Added callable `issueEmployeeInvitation` in `asia-southeast1`.
- Added server-side role, tenant, employee status, account-state, and invite-role validation.
- Added cryptographically random 7-day activation codes generated only by the backend.
- Added protected Firestore `mail` queue documents compatible with Firebase Trigger Email.
- Added Veyra-branded employee invitation email content.
- Added Flutter `cloud_functions` integration.
- Added Firebase Trigger Email setup documentation.

### Security
- Flutter clients can no longer create or revoke invitation records.
- Company and role authorization for invitations now runs with trusted Admin SDK data.
- SMTP credentials remain outside the Flutter application and can be managed by Firebase Trigger Email.
- Firestore denies client access to the mail queue.

### Changed
- Employee Directory invitation actions now call Cloud Functions instead of writing invitation records directly.
- Invitation UI now reports queued email delivery while retaining the activation code as an operational fallback.
- Firebase Functions use the Singapore region (`asia-southeast1`).
- Bumped the application version to `1.8.0+15`.


## [1.7.0] - 2026-08-25

### Added
- Added secure employee invitation issuance for company owners and HR administrators.
- Added 7-day invitation codes with automatic revocation when a newer code is issued.
- Added employee account activation using invitation code, work email, and Firebase Email/Password authentication.
- Added invitation redemption that atomically binds Firebase UID, tenant company, employee record, and HRMS role.
- Added an invitation activation entry point to the Veyra HRMS sign-in experience.
- Added invitation status awareness to the Employee Directory with invite and re-invite actions.

### Security
- Added top-level invitation Security Rules scoped to company admins or the invited Firebase email.
- Added invited-user identity creation rules that validate companyId, employeeId, role, email, invitation status, and acceptedBy UID.
- Added controlled employee activation rules that allow only the invited Firebase account to claim the matching pending employee profile.
- Employee and manager roles still cannot be self-selected through public registration.

### Changed
- Employee pre-onboarding now creates a real invitation immediately after the directory profile is created.
- Employee onboarding state now progresses from `pendingInvite` → `invited` → `active`.
- Bumped the application version to `1.7.0+14`.

### Architecture note
- Invitation delivery is intentionally represented by a secure activation code in this phase. Automated email delivery should be added through a trusted backend/Cloud Function rather than by embedding mail credentials in the Flutter client.


## [1.6.1] - 2026-08-25

### Fixed
- Fixed the Phase 006 dashboard build error caused by a stale required `hrmsRole` parameter on the today-attendance presentation card.
- Cleaned up control-flow lint issues in Employee Directory and Organization Management.
- Restored the analyzer baseline for the Phase 006 company and employee management increment.

### Changed
- Bumped the application version to `1.6.1+13`.


## [1.6.0] - 2026-08-25

### Added
- Added the first production-oriented Veyra HRMS company administration module backed by tenant-scoped Cloud Firestore data.
- Added Company Profile management with registration number and company time-zone settings.
- Added Branch Management with active/inactive status, branch codes, and addresses.
- Added Department Management with active/inactive status and department codes.
- Added a Firestore Employee Directory with search, workforce summary, job title, branch, department, employment status, and HRMS role metadata.
- Added secure employee pre-onboarding records with `pendingInvite` state instead of creating Firebase Auth users from an administrator client session.
- New company workspaces now bootstrap `Head Office` and `Management` organization records automatically.
- Added company-administration entry points to the owner/HR dashboard.

### Changed
- Dashboard authorization now uses the real `HrmsRole` instead of relying only on the temporary `boss`/`employee` compatibility role.
- Attendance QR generation and validation now use the signed-in tenant `companyId`; the previous hard-coded company identifier has been removed.
- Updated the application title constant from `Workday QR` to `Veyra HRMS`.
- Bumped the application version to `1.6.0+12`.

### Security
- Tightened Firestore employee creation so company admins can create only pre-onboarded `employee`, `manager`, or `hrAdmin` records and cannot self-create `companyOwner` or `superAdmin` identities.
- Added explicit tenant rules for branches and departments and removed the generic tenant write fallback.
- Company A organization and employee documents remain inaccessible to authenticated users belonging to Company B.

### Architecture note
- Organization and Employee Management use feature-first domain/data/application/presentation layers. Account invitations are intentionally deferred to a server-mediated flow rather than using `FirebaseAuth.createUserWithEmailAndPassword` from the HR administrator's client.


## [1.5.3] - 2026-08-25

### Changed
- Redesigned the company workspace registration page to match the original Veyra HRMS sign-in visual language.
- Added the same pale blue gradient, circular HR briefcase mark, white rounded form surface, blue field icons, soft input fills, and cyan-to-blue primary action treatment.
- Improved responsive registration spacing for mobile and browser layouts while preserving Firebase company-owner registration and multi-tenant identity behavior.
- Bumped the application version to `1.5.3+11`.


## [1.5.2] - 2026-08-25

### Changed
- Restored the original `qr_scanning` sign-in visual language as the foundation for Veyra HRMS.
- Rebranded the original attendance login presentation to `Veyra HRMS` without replacing its familiar gradient, centered form card, rounded fields, and blue sign-in treatment.
- Kept Firebase email/password authentication, tenant identity restoration, workspace registration, and password reset functionality.
- Restored the existing application theme so the authentication redesign does not unintentionally restyle the rest of the HRMS.
- Bumped the application version to `1.5.2+10`.

### Architecture note
- This increment changes presentation only; the Firebase Auth and multi-tenant identity foundation from Phase 005 remains authoritative.


## [1.5.1] - 2026-08-25

### Added
- Introduced the Veyra HRMS brand foundation and reusable authentication design system.
- Added a responsive authentication shell with a dedicated desktop brand panel and mobile-first layout.
- Added Firebase password-reset UX from the sign-in screen.
- Added reusable authentication error presentation and Veyra wordmark components.

### Changed
- Redesigned Firebase sign-in as the Veyra HRMS professional SaaS entry experience while preserving tenant-aware authentication.
- Redesigned company-owner onboarding as a Veyra workspace setup flow without exposing role self-selection.
- Applied shared Veyra design tokens and Material 3 controls to authentication surfaces.
- Bumped the application version to `1.5.1+9`.

### Architecture note
- Authentication presentation is now separated into reusable feature widgets; Firebase identity, tenant creation, and authorization behavior remain unchanged.


## [1.5.0] - 2026-08-25

### Added
- Added Firebase Email/Password authentication as the primary HRMS identity provider.
- Added multi-tenant identity models for `uid`, `companyId`, `employeeId`, and professional HRMS roles.
- Added company-owner onboarding that creates the company tenant, owner user profile, and owner employee record in one Firestore batch.
- Added Firestore security rules establishing tenant-aware access boundaries and preventing client-side role escalation.
- Added persisted tenant/session metadata for the active company and Firebase identity.

### Changed
- Replaced the legacy Employee ID/password login UI with work-email Firebase sign-in.
- Reworked public registration into company workspace creation; public users can no longer self-select Manager/Employee privileges.
- Added a compatibility hydration bridge so the existing Dashboard, Attendance, Leave, and Claims modules continue working while their repositories are migrated to Firestore incrementally.
- Firebase sign-out now clears both Firebase Auth and local HRMS session state.
- Cleaned the Phase 003 analyzer lint findings in Leave and Claims code.

### Security
- New tenants assign the first registered account `companyOwner`; `superAdmin` cannot be self-assigned by client registration.
- User self-updates cannot change their `companyId`, `employeeId`, or `role`.
- Company-scoped reads require an active authenticated identity belonging to the same tenant.

## [1.4.1] - 2026-08-25

### Fixed
- Replaced the placeholder Firebase options for Android and Web with the verified SDK configuration from Firebase project `forum-d8b06`.
- Worked around the FlutterFire CLI 1.4.1 `android/app/build.gradle` lookup failure on the project's Kotlin DSL Android app module.

### Changed
- Android now initializes Firebase using the registered `com.qrscanning.hrms` app configuration.
- Web now initializes Firebase using the registered `qr_scanning (web)` app configuration.
- iOS, macOS, and Windows remain intentionally unconfigured in Dart until their platform-specific SDK values are verified.
- Bumped the application version to `1.4.1+7`.

### Architecture note
- This increment only establishes verified Firebase connectivity. HRMS business repositories remain local until tenant-aware Auth, Firestore schema, and Security Rules are introduced.

## [1.4.0] - 2026-08-25

### Added
- Added the FlutterFire foundation for Firebase Core, Authentication, Cloud Firestore, Cloud Storage, and Cloud Messaging.
- Added a centralized Firebase bootstrap layer that initializes before the app starts and exposes connection state without breaking the existing local HRMS flow when Firebase has not been configured yet.
- Added guarded Firebase service accessors for Auth, Firestore, Storage, and Messaging so feature modules do not create Firebase singletons directly.
- Added a FlutterFire-compatible placeholder `firebase_options.dart`; `flutterfire configure` can replace it with the real project configuration.
- Added permanent Firebase setup documentation under `docs/setup/FIREBASE_SETUP.md`.

### Changed
- Changed the Android application ID from the Flutter template identifier to `com.qrscanning.hrms` before Firebase registration.
- Changed the Apple bundle ID from the Flutter template identifier to `com.qrscanning.hrms` before Firebase registration.
- Firebase initialization now runs as part of application bootstrap before `QrScanningApp` starts.
- Bumped the application version to `1.4.0+6`.

### Architecture note
- Existing employee/attendance/leave/claims repositories intentionally remain local in this phase. Firebase connectivity is established first; tenant-aware Firestore schema and Security Rules will be introduced before HR data is migrated.

## [1.3.0] - 2026-08-25

### Added
- Added feature-first Leave and Claims modules with domain, data, application, and presentation layers.
- Added per-employee leave and expense-claim storage so accounts on the same device no longer share request data.
- Added legacy local-data migration for existing `leave_requests` and `claims` records.
- Added employee request history, pending/approved summaries, and persistent approval status.
- Added a manager approval center for boss accounts with Leave and Claims tabs.
- Added approve/reject workflows with reviewer identity, review timestamp, and optional review notes.

### Changed
- Replaced the legacy one-shot Leave and Claims forms with self-service pages that keep request history visible after submission.
- Kept `LeaveScreen` and `ClaimsScreen` as compatibility adapters while moving business logic into dedicated feature modules.
- Added a Manager approvals entry to the boss dashboard.
- Bumped the application version to `1.3.0+5`.

### Architecture note
- Leave and Claims now follow the target feature-first structure. Local SharedPreferences repositories remain demo persistence and can later be replaced by API-backed repositories without rewriting presentation logic.

## [1.2.1] - 2026-08-25

### Fixed
- Replaced the obsolete default Flutter counter widget test with an application-level signed-out routing smoke test.
- Updated deprecated color alpha calls from `withOpacity` to `withValues`.
- Updated `DropdownButtonFormField` initialization to the current Flutter API.
- Fixed async `BuildContext` usage and flow-control lint issues in meeting-room date/time selection.
- Removed unused imports and cleaned separator callback parameters and string interpolation.
- Updated nullable widget collection handling to use Dart's null-aware collection element syntax.
- Bumped the application version to `1.2.1+4`.

### Quality
- Phase 002 analyzer cleanup now targets a zero-warning, zero-error baseline on the current Flutter/Dart toolchain.

## [1.2.0] - 2026-08-25

### Added
- Added a dedicated dashboard feature with domain, application, and presentation layers.
- Added a personalized employee header showing employee name, department, and role.
- Added a live today-attendance card with clock-in, clock-out, work schedule, and completion state.
- Added monthly attendance indicators for logged days, late arrivals, and early departures.
- Added quick-access work tools while keeping attendance history one tap away.
- Added pull-to-refresh support for dashboard data.

### Changed
- Replaced the legacy icon-only home menu with a production-style workplace dashboard.
- Dashboard attendance actions now switch to the existing Scan/Code navigation tab instead of pushing duplicate attendance pages.
- Returning to the Home tab now refreshes attendance data so a completed scan is reflected immediately.
- Bumped the application version to `1.2.0+3`.

### Architecture note
- Dashboard aggregation now lives outside UI widgets through `DashboardService`, keeping presentation code focused on rendering and navigation.

## [1.1.0] - 2026-08-25

### Added
- Introduced a production-oriented app layer with centralized app bootstrap, navigation, theme, constants, and session storage.
- Added a dedicated attendance QR domain model with company validation, expiry handling, clock-skew validation, and nonce-based payload generation.
- Added per-user attendance summaries and safer record parsing.
- Added scanner flashlight and camera-switch controls.
- Added pull-to-refresh and status chips to attendance history.

### Changed
- Moved the role-aware bottom navigation shell out of `main.dart` into the app navigation layer.
- Replaced broad preference clearing on logout with session-only cleanup so unrelated local app data is preserved.
- Isolated attendance records by signed-in user instead of storing all employees in one shared record list.
- Added migration of legacy attendance records into the current signed-in user's scoped storage.
- Centralized login session persistence through `SessionStore`.
- Refreshed attendance-code and scanner screens to use the shared QR validation contract.

### Fixed
- Prevented attendance history from mixing records between different employee accounts on the same device.
- Prevented malformed, expired, future-dated, and wrong-company QR payloads from triggering attendance.
- Removed the scanner's back-navigation behavior that could incorrectly reset the main navigation stack.

### Architecture note
- The current app still uses local/demo repositories for user and business data. QR validation is structurally improved but is not cryptographically secure without a trusted backend. A production backend should issue signed, one-time attendance challenges and persist attendance server-side.
