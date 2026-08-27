"use strict";

const crypto = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {setGlobalOptions} = require("firebase-functions/v2/options");
const nodemailer = require("nodemailer");

initializeApp();

setGlobalOptions({
  region: "asia-southeast1",
  memory: "256MiB",
  timeoutSeconds: 30,
  maxInstances: 20,
});

const db = getFirestore();
const smtpPassword = defineSecret("VEYRA_SMTP_PASSWORD");
const SMTP_USER = "veyra.hrms@gmail.com";
const ALLOWED_INVITE_ROLES = new Set(["employee", "manager", "hrAdmin"]);
const ADMIN_ROLES = new Set(["companyOwner", "hrAdmin"]);

function asNonEmptyString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }
  return value.trim();
}

function htmlEscape(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}


async function createUserNotification({
  companyId,
  uid,
  type,
  title,
  body,
  targetType = null,
  targetId = null,
}) {
  if (!companyId || !uid) return;
  await db
    .collection("companies")
    .doc(companyId)
    .collection("userNotifications")
    .doc(uid)
    .collection("items")
    .add({
      companyId,
      uid,
      type,
      title,
      body,
      targetType,
      targetId,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
}

async function notificationRecipientsForRoles(companyId, roles) {
  const snapshot = await db
    .collection("identities")
    .where("companyId", "==", companyId)
    .where("isActive", "==", true)
    .get();
  return snapshot.docs
    .filter((doc) => roles.includes(doc.data().role))
    .map((doc) => doc.id);
}



async function writeAuditLog({
  companyId,
  actor,
  module,
  action,
  targetType = "",
  targetId = "",
  summary = "",
  result = "success",
  metadata = null,
}) {
  if (!companyId || !actor?.uid) return;

  await db
    .collection("companies")
    .doc(companyId)
    .collection("auditLogs")
    .add({
      companyId,
      actorUid: actor.uid,
      actorEmployeeId: actor.employeeId || "",
      actorName: actor.displayName || actor.employeeId || "User",
      actorRole: actor.role || "",
      module,
      action,
      targetType,
      targetId,
      summary,
      result,
      metadata,
      createdAt: FieldValue.serverTimestamp(),
    });
}

function auditActor(request, caller) {
  return {
    uid: request.auth?.uid || "",
    employeeId: caller?.employeeId || "",
    displayName: caller?.displayName || "",
    role: caller?.role || "",
  };
}


exports.issueEmployeeInvitation = onCall(
  {
    enforceAppCheck: false,
    secrets: [smtpPassword],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in before inviting employees.");
    }

    const employeeId = asNonEmptyString(request.data?.employeeId, "employeeId")
      .toUpperCase();

    const callerRef = db.collection("users").doc(request.auth.uid);
    const callerSnapshot = await callerRef.get();
    const caller = callerSnapshot.data();

    if (!caller || caller.isActive !== true) {
      throw new HttpsError("permission-denied", "Your HRMS account is inactive.");
    }
    if (!ADMIN_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "Only the company owner or HR administrator can invite employees.",
      );
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeRef = db
      .collection("companies")
      .doc(companyId)
      .collection("employees")
      .doc(employeeId);
    const employeeSnapshot = await employeeRef.get();
    const employee = employeeSnapshot.data();

    if (!employee) {
      throw new HttpsError("not-found", "Employee profile was not found.");
    }
    if (employee.employmentStatus !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "Inactive employees cannot receive invitations.",
      );
    }
    if (typeof employee.uid === "string" && employee.uid.length > 0) {
      throw new HttpsError(
        "already-exists",
        "This employee already has an active Veyra account.",
      );
    }
    if (!ALLOWED_INVITE_ROLES.has(employee.role)) {
      throw new HttpsError(
        "failed-precondition",
        "This employee role cannot be activated through an invitation.",
      );
    }

    const email = asNonEmptyString(employee.email, "employee email").toLowerCase();
    const displayName = asNonEmptyString(employee.displayName, "displayName");
    const invitationId = crypto.randomBytes(18).toString("base64url");
    const invitationRef = db.collection("invitations").doc(invitationId);
    const expiresAtDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const expiresAt = Timestamp.fromDate(expiresAtDate);

    const oldInvitationId =
      typeof employee.invitationId === "string" ? employee.invitationId : null;

    await db.runTransaction(async (transaction) => {
      const latestEmployeeSnapshot = await transaction.get(employeeRef);
      const latestEmployee = latestEmployeeSnapshot.data();

      if (!latestEmployee) {
        throw new HttpsError("not-found", "Employee profile was not found.");
      }
      if (latestEmployee.uid) {
        throw new HttpsError(
          "already-exists",
          "This employee already has an active Veyra account.",
        );
      }

      if (oldInvitationId) {
        const oldInvitationRef = db.collection("invitations").doc(oldInvitationId);
        const oldInvitationSnapshot = await transaction.get(oldInvitationRef);
        if (
          oldInvitationSnapshot.exists &&
          oldInvitationSnapshot.data()?.status === "pending"
        ) {
          transaction.update(oldInvitationRef, {
            status: "revoked",
            revokedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.create(invitationRef, {
        companyId,
        employeeId,
        email,
        displayName,
        role: latestEmployee.role,
        status: "pending",
        createdBy: request.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt,
      });

      transaction.update(employeeRef, {
        invitationId,
        onboardingStatus: "invited",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const companySnapshot = await db.collection("companies").doc(companyId).get();
    const companyName =
      companySnapshot.data()?.name ||
      companySnapshot.data()?.companyName ||
      "your company";

    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: {
        user: SMTP_USER,
        pass: smtpPassword.value(),
      },
    });

    const subject = `You're invited to ${companyName} on Veyra HRMS`;
    const text =
      `Hello ${displayName},\n\n` +
      `${companyName} invited you to Veyra HRMS.\n\n` +
      `Activation code: ${invitationId}\n` +
      `Work email: ${email}\n` +
      `This code expires in 7 days.\n\n` +
      `Open Veyra HRMS, choose "Have an invitation? Activate account", ` +
      `and enter this code with your work email.\n`;
    const html =
      `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;` +
      `color:#25364d">` +
      `<h2 style="margin-bottom:6px">Veyra HRMS</h2>` +
      `<p>Hello ${htmlEscape(displayName)},</p>` +
      `<p><strong>${htmlEscape(companyName)}</strong> invited you to join ` +
      `their Veyra HRMS workspace.</p>` +
      `<div style="background:#f3f8ff;border-radius:14px;padding:18px;` +
      `margin:22px 0">` +
      `<div style="font-size:12px;color:#718096">ACTIVATION CODE</div>` +
      `<div style="font-size:21px;font-weight:700;letter-spacing:.5px;` +
      `margin-top:6px">${htmlEscape(invitationId)}</div>` +
      `</div>` +
      `<p>Open Veyra HRMS and choose <strong>Have an invitation? ` +
      `Activate account</strong>. Sign up with <strong>${htmlEscape(email)}` +
      `</strong>.</p>` +
      `<p style="color:#718096">This invitation expires in 7 days. ` +
      `A newer invitation automatically revokes this code.</p>` +
      `</div>`;

    try {
      const info = await transporter.sendMail({
        from: `"Veyra HRMS" <${SMTP_USER}>`,
        to: email,
        subject,
        text,
        html,
      });

      await invitationRef.update({
        emailDelivery: {
          state: "success",
          messageId: info.messageId || null,
          sentAt: FieldValue.serverTimestamp(),
        },
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await invitationRef.update({
        emailDelivery: {
          state: "error",
          error: String(error?.message || error),
          failedAt: FieldValue.serverTimestamp(),
        },
        updatedAt: FieldValue.serverTimestamp(),
      });

      throw new HttpsError(
        "internal",
        "The invitation was created, but the email could not be sent. Try Re-invite after checking the mail configuration.",
      );
    }

    return {
      invitationId,
      companyId,
      employeeId,
      email,
      displayName,
      role: employee.role,
      expiresAt: expiresAtDate.toISOString(),
      emailSent: true,
    };
  },
);


const ATTENDANCE_ADMIN_ROLES = new Set(["companyOwner", "hrAdmin", "manager"]);

function attendanceSettingsDefaults(timeZone = "Asia/Kuala_Lumpur") {
  return {
    workStartMinutes: 9 * 60,
    workEndMinutes: 18 * 60,
    graceMinutes: 5,
    requireQr: false,
    timeZone,
  };
}

function localDateParts(date, timeZone) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });

  const parts = Object.fromEntries(
    formatter.formatToParts(date)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );

  return {
    dateKey: `${parts.year}-${parts.month}-${parts.day}`,
    minuteOfDay: Number(parts.hour) * 60 + Number(parts.minute),
  };
}

async function loadCaller(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to Veyra HRMS first.");
  }

  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  const caller = snapshot.data();

  if (!caller || caller.isActive !== true) {
    throw new HttpsError("permission-denied", "Your Veyra HRMS account is inactive.");
  }

  return caller;
}

async function loadAttendanceSettings(companyId) {
  const companyRef = db.collection("companies").doc(companyId);
  const [companySnapshot, settingsSnapshot] = await Promise.all([
    companyRef.get(),
    companyRef.collection("settings").doc("attendance").get(),
  ]);

  const company = companySnapshot.data() || {};
  const defaults = attendanceSettingsDefaults(
    company.timeZone || "Asia/Kuala_Lumpur",
  );

  return {
    ...defaults,
    ...(settingsSnapshot.data() || {}),
  };
}

exports.updateAttendanceSettings = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);

    if (!ATTENDANCE_ADMIN_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to manage attendance settings.",
      );
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const workStartMinutes = Number(request.data?.workStartMinutes);
    const workEndMinutes = Number(request.data?.workEndMinutes);
    const graceMinutes = Number(request.data?.graceMinutes);
    const requireQr = request.data?.requireQr === true;
    const timeZone = asNonEmptyString(request.data?.timeZone, "timeZone");

    if (
      !Number.isInteger(workStartMinutes) ||
      !Number.isInteger(workEndMinutes) ||
      !Number.isInteger(graceMinutes) ||
      workStartMinutes < 0 ||
      workStartMinutes >= 1440 ||
      workEndMinutes <= workStartMinutes ||
      workEndMinutes >= 1440 ||
      graceMinutes < 0 ||
      graceMinutes > 120
    ) {
      throw new HttpsError("invalid-argument", "Attendance settings are invalid.");
    }

    await db
      .collection("companies")
      .doc(companyId)
      .collection("settings")
      .doc("attendance")
      .set(
        {
          workStartMinutes,
          workEndMinutes,
          graceMinutes,
          requireQr,
          timeZone,
          updatedBy: request.auth.uid,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "attendance",
      action: "updateAttendanceSettings",
      targetType: "attendanceSettings",
      targetId: "attendance",
      summary: "Updated attendance settings.",
    });
    return {updated: true};
  },
);

exports.issueAttendanceQr = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);

    if (!ATTENDANCE_ADMIN_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to display the attendance QR.",
      );
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const token = crypto.randomBytes(24).toString("base64url");
    const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
    const expiresAtDate = new Date(Date.now() + 90 * 1000);

    await db
      .collection("companies")
      .doc(companyId)
      .collection("attendanceQr")
      .doc("current")
      .set({
        tokenHash,
        issuedBy: request.auth.uid,
        issuedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromDate(expiresAtDate),
      });

    return {
      token,
      expiresAt: expiresAtDate.toISOString(),
    };
  },
);

exports.clockAttendance = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const source = request.data?.source === "qr" ? "qr" : "app";

    const employeeRef = db
      .collection("companies")
      .doc(companyId)
      .collection("employees")
      .doc(employeeId);
    const employeeSnapshot = await employeeRef.get();
    const employee = employeeSnapshot.data();

    if (!employee || employee.employmentStatus !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "Your employee profile is not active.",
      );
    }

    const settings = await loadAttendanceSettings(companyId);

    if (settings.requireQr && source !== "qr") {
      throw new HttpsError(
        "failed-precondition",
        "Your company requires the secure attendance QR.",
      );
    }

    if (source === "qr") {
      const token = asNonEmptyString(request.data?.qrToken, "qrToken");
      const qrRef = db
        .collection("companies")
        .doc(companyId)
        .collection("attendanceQr")
        .doc("current");
      const qrSnapshot = await qrRef.get();
      const qr = qrSnapshot.data();
      const expectedHash =
        crypto.createHash("sha256").update(token).digest("hex");

      if (
        !qr ||
        qr.tokenHash !== expectedHash ||
        !(qr.expiresAt instanceof Timestamp) ||
        qr.expiresAt.toDate().getTime() < Date.now()
      ) {
        throw new HttpsError(
          "failed-precondition",
          "This attendance QR is invalid or expired.",
        );
      }
    }

    const now = Timestamp.now();
    const local = localDateParts(now.toDate(), settings.timeZone);

    const leaveSnapshot = await db
      .collection("companies")
      .doc(companyId)
      .collection("leaveRequests")
      .where("employeeId", "==", employeeId)
      .get();
    const approvedLeave = leaveSnapshot.docs
      .map((doc) => doc.data())
      .find(
        (leave) =>
          leave.status === "approved" &&
          String(leave.startDateKey || "") <= local.dateKey &&
          String(leave.endDateKey || "") >= local.dateKey,
      );

    if (approvedLeave) {
      throw new HttpsError(
        "failed-precondition",
        `You are on approved ${approvedLeave.typeName || "leave"} today.`,
      );
    }

    const attendanceId = `${employeeId}_${local.dateKey}`;
    const attendanceRef = db
      .collection("companies")
      .doc(companyId)
      .collection("attendance")
      .doc(attendanceId);

    const result = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(attendanceRef);
      const current = snapshot.data();

      if (!current || !current.clockInAt) {
        const lateAfter =
          Number(settings.workStartMinutes) + Number(settings.graceMinutes);
        const status = local.minuteOfDay > lateAfter ? "late" : "onTime";

        transaction.set(
          attendanceRef,
          {
            companyId,
            employeeId,
            employeeName: employee.displayName || caller.displayName || "Employee",
            department: employee.department || caller.department || "",
            branch: employee.branch || caller.branch || "",
            dateKey: local.dateKey,
            timeZone: settings.timeZone,
            clockInAt: now,
            clockInStatus: status,
            clockOutAt: null,
            clockOutStatus: "",
            workedMinutes: null,
            source,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );

        return {
          action: "clockIn",
          status,
          message:
            status === "late" ?
              "Clock in recorded. You are marked late." :
              "Clock in recorded successfully.",
        };
      }

      if (current.clockOutAt) {
        throw new HttpsError(
          "already-exists",
          "You have already completed attendance today.",
        );
      }

      const clockInAt = current.clockInAt;
      const workedMinutes = Math.max(
        0,
        Math.floor((now.toMillis() - clockInAt.toMillis()) / 60000),
      );
      const status =
        local.minuteOfDay < Number(settings.workEndMinutes) ? "early" : "normal";

      transaction.update(attendanceRef, {
        clockOutAt: now,
        clockOutStatus: status,
        workedMinutes,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {
        action: "clockOut",
        status,
        message:
          status === "early" ?
            "Clock out recorded. Early leave marked." :
            "Clock out recorded successfully.",
      };
    });

    return {
      ...result,
      dateKey: local.dateKey,
    };
  },
);


exports.redeemEmployeeInvitation = onCall(
  {enforceAppCheck: false},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Create your Firebase account before activating the invitation.",
      );
    }

    const invitationId = asNonEmptyString(
      request.data?.invitationId,
      "invitationId",
    );
    const authenticatedEmail =
      String(request.auth.token.email || "").trim().toLowerCase();

    if (!authenticatedEmail) {
      throw new HttpsError(
        "failed-precondition",
        "Your Firebase account has no verified work email.",
      );
    }

    const invitationRef = db.collection("invitations").doc(invitationId);
    const userRef = db.collection("users").doc(request.auth.uid);

    return db.runTransaction(async (transaction) => {
      const invitationSnapshot = await transaction.get(invitationRef);
      const invitation = invitationSnapshot.data();

      if (!invitation) {
        throw new HttpsError("not-found", "Invitation code is invalid.");
      }

      const companyId = asNonEmptyString(
        invitation.companyId,
        "invitation companyId",
      );
      const employeeId = asNonEmptyString(
        invitation.employeeId,
        "invitation employeeId",
      );
      const expectedEmail =
        String(invitation.email || "").trim().toLowerCase();
      const role = asNonEmptyString(invitation.role, "invitation role");

      if (invitation.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "This invitation is no longer active.",
        );
      }

      if (
        !(invitation.expiresAt instanceof Timestamp) ||
        invitation.expiresAt.toDate().getTime() < Date.now()
      ) {
        throw new HttpsError(
          "failed-precondition",
          "This invitation has expired. Ask HR to send a new invitation.",
        );
      }

      if (expectedEmail !== authenticatedEmail) {
        throw new HttpsError(
          "permission-denied",
          "This invitation belongs to another work email.",
        );
      }

      if (!ALLOWED_INVITE_ROLES.has(role)) {
        throw new HttpsError(
          "failed-precondition",
          "This invitation contains an unsupported HRMS role.",
        );
      }

      const employeeRef = db
        .collection("companies")
        .doc(companyId)
        .collection("employees")
        .doc(employeeId);

      const [employeeSnapshot, existingUserSnapshot] = await Promise.all([
        transaction.get(employeeRef),
        transaction.get(userRef),
      ]);

      const employee = employeeSnapshot.data();

      if (!employee) {
        throw new HttpsError(
          "not-found",
          "The invited employee profile was not found.",
        );
      }

      if (existingUserSnapshot.exists) {
        throw new HttpsError(
          "already-exists",
          "This Firebase account is already linked to Veyra HRMS.",
        );
      }

      if (employee.employmentStatus !== "active") {
        throw new HttpsError(
          "failed-precondition",
          "This employee profile is inactive.",
        );
      }

      if (employee.uid) {
        throw new HttpsError(
          "already-exists",
          "This employee already has an activated account.",
        );
      }

      if (employee.invitationId !== invitationId) {
        throw new HttpsError(
          "failed-precondition",
          "A newer invitation has replaced this activation code.",
        );
      }

      if (String(employee.email || "").trim().toLowerCase() !== expectedEmail) {
        throw new HttpsError(
          "failed-precondition",
          "The employee work email no longer matches this invitation.",
        );
      }

      if (employee.role !== role) {
        throw new HttpsError(
          "failed-precondition",
          "The employee role changed after this invitation was issued.",
        );
      }

      const displayName =
        employee.displayName || invitation.displayName || "Employee";
      const department = employee.department || "";
      const departmentId = employee.departmentId || "";
      const branch = employee.branch || "";
      const branchId = employee.branchId || "";

      transaction.set(userRef, {
        companyId,
        employeeId,
        email: expectedEmail,
        displayName,
        department,
        departmentId,
        branch,
        branchId,
        role,
        isActive: true,
        invitationId,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(employeeRef, {
        uid: request.auth.uid,
        onboardingStatus: "active",
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(invitationRef, {
        status: "accepted",
        acceptedBy: request.auth.uid,
        acceptedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {
        uid: request.auth.uid,
        companyId,
        employeeId,
        email: expectedEmail,
        displayName,
        department,
        branch,
        role,
        isActive: true,
      };
    });
  },
);


const LEAVE_APPROVER_ROLES = new Set(["companyOwner", "hrAdmin", "manager"]);
const LEAVE_POLICY_ADMIN_ROLES = new Set(["companyOwner", "hrAdmin"]);

function defaultLeaveTypes() {
  return [
    {
      id: "annual",
      name: "Annual Leave",
      quotaDays: 14,
      paid: true,
      requiresAttachment: false,
    },
    {
      id: "sick",
      name: "Sick Leave",
      quotaDays: 14,
      paid: true,
      requiresAttachment: true,
    },
    {
      id: "emergency",
      name: "Emergency Leave",
      quotaDays: 3,
      paid: true,
      requiresAttachment: false,
    },
    {
      id: "unpaid",
      name: "Unpaid Leave",
      quotaDays: null,
      paid: false,
      requiresAttachment: false,
    },
  ];
}

function parseDateKey(value, fieldName) {
  const raw = asNonEmptyString(value, fieldName);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must use YYYY-MM-DD.`,
    );
  }
  const date = new Date(`${raw}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }
  return {raw, date};
}

function businessDayCount(start, end) {
  let cursor = new Date(start.getTime());
  let days = 0;

  while (cursor.getTime() <= end.getTime()) {
    const weekday = cursor.getUTCDay();
    if (weekday !== 0 && weekday !== 6) days++;
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return days;
}

async function loadLeavePolicy(companyId) {
  const ref = db
    .collection("companies")
    .doc(companyId)
    .collection("settings")
    .doc("leave");
  const snapshot = await ref.get();
  const data = snapshot.data();
  const types =
    Array.isArray(data?.types) && data.types.length > 0 ?
      data.types :
      defaultLeaveTypes();

  return {ref, types};
}

function normalizeLeaveTypes(rawTypes) {
  if (!Array.isArray(rawTypes) || rawTypes.length < 1 || rawTypes.length > 12) {
    throw new HttpsError(
      "invalid-argument",
      "Leave policy must contain between 1 and 12 leave types.",
    );
  }

  const seen = new Set();
  return rawTypes.map((raw) => {
    const id = asNonEmptyString(raw?.id, "leave type id")
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, "");
    const name = asNonEmptyString(raw?.name, "leave type name");
    if (!id || seen.has(id)) {
      throw new HttpsError("invalid-argument", "Leave type IDs must be unique.");
    }
    seen.add(id);

    let quotaDays = null;
    if (raw?.quotaDays !== null && raw?.quotaDays !== undefined) {
      quotaDays = Number(raw.quotaDays);
      if (
        !Number.isFinite(quotaDays) ||
        quotaDays < 0 ||
        quotaDays > 365
      ) {
        throw new HttpsError(
          "invalid-argument",
          `${name} quota must be between 0 and 365 days.`,
        );
      }
    }

    return {
      id,
      name,
      quotaDays,
      paid: raw?.paid === true,
      requiresAttachment: raw?.requiresAttachment === true,
    };
  });
}

function balanceId(employeeId, year) {
  return `${employeeId}_${year}`;
}

function seedBalance(types) {
  const entitlements = {};
  const used = {};
  const reserved = {};

  for (const type of types) {
    if (type.quotaDays !== null && type.quotaDays !== undefined) {
      entitlements[type.id] = Number(type.quotaDays);
    }
    used[type.id] = 0;
    reserved[type.id] = 0;
  }

  return {entitlements, used, reserved};
}

function leaveOverviewPayload(year, types, balance) {
  return {
    year,
    types,
    balances: types.map((type) => ({
      typeId: type.id,
      typeName: type.name,
      entitlement:
        type.quotaDays === null || type.quotaDays === undefined ?
          null :
          Number(balance.entitlements?.[type.id] ?? type.quotaDays),
      used: Number(balance.used?.[type.id] ?? 0),
      reserved: Number(balance.reserved?.[type.id] ?? 0),
    })),
  };
}

exports.getLeaveOverview = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const year = new Date().getUTCFullYear();
    const {types} = await loadLeavePolicy(companyId);
    const balanceRef = db
      .collection("companies")
      .doc(companyId)
      .collection("leaveBalances")
      .doc(balanceId(employeeId, year));

    let balanceSnapshot = await balanceRef.get();
    if (!balanceSnapshot.exists) {
      const seeded = seedBalance(types);
      await balanceRef.set({
        companyId,
        employeeId,
        year,
        ...seeded,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      balanceSnapshot = await balanceRef.get();
    }

    return leaveOverviewPayload(year, types, balanceSnapshot.data() || {});
  },
);

exports.updateLeavePolicy = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!LEAVE_POLICY_ADMIN_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "Only company owners or HR administrators can change leave policy.",
      );
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const types = normalizeLeaveTypes(request.data?.types);
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("settings")
      .doc("leave");

    await ref.set(
      {
        types,
        updatedBy: request.auth.uid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    const year = new Date().getUTCFullYear();
    const balancesSnapshot = await db
      .collection("companies")
      .doc(companyId)
      .collection("leaveBalances")
      .where("year", "==", year)
      .get();

    await Promise.all(
      balancesSnapshot.docs.map(async (doc) => {
        const current = doc.data();
        const entitlements = {};
        for (const type of types) {
          if (type.quotaDays !== null && type.quotaDays !== undefined) {
            entitlements[type.id] = Number(type.quotaDays);
          }
        }
        await doc.ref.update({
          entitlements,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }),
    );

    return {updated: true, balancesUpdated: balancesSnapshot.size};
  },
);

exports.submitLeaveRequest = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const reason = asNonEmptyString(request.data?.reason, "reason");
    const typeId = asNonEmptyString(request.data?.typeId, "typeId");
    const duration = asNonEmptyString(request.data?.duration, "duration");
    const start = parseDateKey(request.data?.startDateKey, "startDateKey");
    const end = parseDateKey(request.data?.endDateKey, "endDateKey");
    const attachmentPath =
      typeof request.data?.attachmentPath === "string" &&
      request.data.attachmentPath.trim().length > 0 ?
        request.data.attachmentPath.trim() :
        null;

    if (
      attachmentPath &&
      !attachmentPath.startsWith(`companies/${companyId}/leave/${employeeId}/`)
    ) {
      throw new HttpsError(
        "permission-denied",
        "Supporting attachment does not belong to this employee.",
      );
    }

    const attendanceSettings = await loadAttendanceSettings(companyId);
    const companyToday = localDateParts(
      new Date(),
      attendanceSettings.timeZone,
    ).dateKey;
    if (start.raw < companyToday) {
      throw new HttpsError(
        "invalid-argument",
        "Leave cannot start in the past.",
      );
    }

    if (start.date.getUTCFullYear() !== end.date.getUTCFullYear()) {
      throw new HttpsError(
        "invalid-argument",
        "Leave requests cannot cross calendar years.",
      );
    }
    if (end.date.getTime() < start.date.getTime()) {
      throw new HttpsError("invalid-argument", "End date is before start date.");
    }

    const allowedDurations = new Set([
      "fullDay",
      "halfDayMorning",
      "halfDayAfternoon",
    ]);
    if (!allowedDurations.has(duration)) {
      throw new HttpsError("invalid-argument", "Leave duration is invalid.");
    }
    if (duration !== "fullDay" && start.raw !== end.raw) {
      throw new HttpsError(
        "invalid-argument",
        "Half-day leave must start and end on the same date.",
      );
    }

    const {types} = await loadLeavePolicy(companyId);
    const type = types.find((item) => item.id === typeId);
    if (!type) {
      throw new HttpsError("invalid-argument", "Leave type is not available.");
    }
    if (type.requiresAttachment && !attachmentPath) {
      throw new HttpsError(
        "failed-precondition",
        `${type.name} requires a supporting attachment.`,
      );
    }

    const daysRequested =
      duration === "fullDay" ?
        businessDayCount(start.date, end.date) :
        0.5;

    if (daysRequested <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "The selected dates contain no working days.",
      );
    }

    const employeeRef = db
      .collection("companies")
      .doc(companyId)
      .collection("employees")
      .doc(employeeId);
    const employeeSnapshot = await employeeRef.get();
    const employee = employeeSnapshot.data();

    if (!employee || employee.employmentStatus !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "Your employee profile is inactive.",
      );
    }

    const existingSnapshot = await db
      .collection("companies")
      .doc(companyId)
      .collection("leaveRequests")
      .where("employeeId", "==", employeeId)
      .get();

    const overlaps = existingSnapshot.docs.some((doc) => {
      const item = doc.data();
      if (!["pending", "approved"].includes(item.status)) return false;
      return (
        String(item.startDateKey || "") <= end.raw &&
        String(item.endDateKey || "") >= start.raw
      );
    });

    if (overlaps) {
      throw new HttpsError(
        "already-exists",
        "You already have a pending or approved leave request for these dates.",
      );
    }

    const year = start.date.getUTCFullYear();
    const balanceRef = db
      .collection("companies")
      .doc(companyId)
      .collection("leaveBalances")
      .doc(balanceId(employeeId, year));
    const requestRef = db
      .collection("companies")
      .doc(companyId)
      .collection("leaveRequests")
      .doc();

    await db.runTransaction(async (transaction) => {
      const balanceSnapshot = await transaction.get(balanceRef);
      const balance = balanceSnapshot.exists ?
        balanceSnapshot.data() :
        {
          companyId,
          employeeId,
          year,
          ...seedBalance(types),
        };

      const entitlements = {...(balance.entitlements || {})};
      const used = {...(balance.used || {})};
      const reserved = {...(balance.reserved || {})};

      if (type.quotaDays !== null && type.quotaDays !== undefined) {
        const entitlement = Number(entitlements[typeId] ?? type.quotaDays);
        const usedDays = Number(used[typeId] ?? 0);
        const reservedDays = Number(reserved[typeId] ?? 0);
        const remaining = entitlement - usedDays - reservedDays;

        if (remaining < daysRequested) {
          throw new HttpsError(
            "failed-precondition",
            `Insufficient ${type.name} balance. ${remaining} day(s) available.`,
          );
        }
        reserved[typeId] = reservedDays + daysRequested;
      }

      transaction.set(
        balanceRef,
        {
          companyId,
          employeeId,
          year,
          entitlements,
          used,
          reserved,
          updatedAt: FieldValue.serverTimestamp(),
          ...(balanceSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
        },
        {merge: true},
      );

      transaction.set(requestRef, {
        companyId,
        employeeId,
        employeeName: employee.displayName || caller.displayName || "Employee",
        department: employee.department || caller.department || "",
        branch: employee.branch || caller.branch || "",
        typeId,
        typeName: type.name,
        duration,
        daysRequested,
        startDateKey: start.raw,
        endDateKey: end.raw,
        year,
        reason,
        attachmentPath,
        status: "pending",
        submittedBy: request.auth.uid,
        submittedAt: FieldValue.serverTimestamp(),
        reviewedAt: null,
        reviewerId: null,
        reviewerName: null,
        reviewNote: null,
        cancelledAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {
      requestId: requestRef.id,
      status: "pending",
      daysRequested,
    };
  },
);

exports.reviewLeaveRequest = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!LEAVE_APPROVER_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to review leave.",
      );
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const requestId = asNonEmptyString(request.data?.requestId, "requestId");
    const decision = asNonEmptyString(request.data?.decision, "decision");
    const note =
      typeof request.data?.note === "string" ?
        request.data.note.trim().slice(0, 1000) :
        "";

    if (!["approved", "rejected"].includes(decision)) {
      throw new HttpsError(
        "invalid-argument",
        "Decision must be approved or rejected.",
      );
    }

    const requestRef = db
      .collection("companies")
      .doc(companyId)
      .collection("leaveRequests")
      .doc(requestId);

    await db.runTransaction(async (transaction) => {
      const requestSnapshot = await transaction.get(requestRef);
      const leave = requestSnapshot.data();

      if (!leave) {
        throw new HttpsError("not-found", "Leave request was not found.");
      }
      if (leave.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "This leave request has already been reviewed.",
        );
      }
      if (leave.employeeId === caller.employeeId) {
        throw new HttpsError(
          "permission-denied",
          "You cannot approve or reject your own leave request.",
        );
      }

      const typeId = asNonEmptyString(leave.typeId, "leave type");
      const daysRequested = Number(leave.daysRequested);
      const year = Number(leave.year);
      const employeeId = asNonEmptyString(leave.employeeId, "employeeId");
      const balanceRef = db
        .collection("companies")
        .doc(companyId)
        .collection("leaveBalances")
        .doc(balanceId(employeeId, year));
      const balanceSnapshot = await transaction.get(balanceRef);
      const balance = balanceSnapshot.data();

      if (!balance) {
        throw new HttpsError(
          "failed-precondition",
          "Employee leave balance was not initialized.",
        );
      }

      const used = {...(balance.used || {})};
      const reserved = {...(balance.reserved || {})};
      const reservedDays = Number(reserved[typeId] ?? 0);
      reserved[typeId] = Math.max(0, reservedDays - daysRequested);

      if (decision === "approved") {
        used[typeId] = Number(used[typeId] ?? 0) + daysRequested;
      }

      transaction.update(balanceRef, {
        used,
        reserved,
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(requestRef, {
        status: decision,
        reviewerId: request.auth.uid,
        reviewerName: caller.displayName || caller.employeeId || "Reviewer",
        reviewNote: note || null,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "leave",
      action: decision === "approved" ? "approveLeave" : "rejectLeave",
      targetType: "leaveRequest",
      targetId: requestId,
      summary: `${decision} leave request ${requestId}.`,
    });
    return {status: decision};
  },
);

exports.cancelLeaveRequest = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const requestId = asNonEmptyString(request.data?.requestId, "requestId");
    const requestRef = db
      .collection("companies")
      .doc(companyId)
      .collection("leaveRequests")
      .doc(requestId);

    await db.runTransaction(async (transaction) => {
      const requestSnapshot = await transaction.get(requestRef);
      const leave = requestSnapshot.data();

      if (!leave || leave.employeeId !== employeeId) {
        throw new HttpsError("not-found", "Leave request was not found.");
      }
      if (leave.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "Only pending leave requests can be cancelled.",
        );
      }

      const typeId = asNonEmptyString(leave.typeId, "leave type");
      const daysRequested = Number(leave.daysRequested);
      const year = Number(leave.year);
      const balanceRef = db
        .collection("companies")
        .doc(companyId)
        .collection("leaveBalances")
        .doc(balanceId(employeeId, year));
      const balanceSnapshot = await transaction.get(balanceRef);
      const balance = balanceSnapshot.data();

      if (balance) {
        const reserved = {...(balance.reserved || {})};
        reserved[typeId] = Math.max(
          0,
          Number(reserved[typeId] ?? 0) - daysRequested,
        );
        transaction.update(balanceRef, {
          reserved,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.update(requestRef, {
        status: "cancelled",
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {status: "cancelled"};
  },
);


const PAYROLL_ADMIN_ROLES = new Set(["companyOwner", "hrAdmin"]);

function payrollMonth(value) {
  const month = asNonEmptyString(value, "month");
  if (!/^\d{4}-\d{2}$/.test(month)) {
    throw new HttpsError("invalid-argument", "Payroll month must use YYYY-MM.");
  }
  const monthNumber = Number(month.slice(5));
  if (monthNumber < 1 || monthNumber > 12) {
    throw new HttpsError("invalid-argument", "Payroll month is invalid.");
  }
  return month;
}

function payrollMoney(value, fieldName) {
  const number = Number(value ?? 0);
  if (!Number.isFinite(number) || number < 0 || number > 1000000) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }
  return Math.round(number * 100) / 100;
}

function monthBounds(month) {
  const [year, monthNumber] = month.split("-").map(Number);
  const start = new Date(Date.UTC(year, monthNumber - 1, 1));
  const end = new Date(Date.UTC(year, monthNumber, 0));
  return {
    startKey: start.toISOString().slice(0, 10),
    endKey: end.toISOString().slice(0, 10),
  };
}

function weekdaysBetween(startKey, endKey, month) {
  const bounds = monthBounds(month);
  const start = new Date(`${startKey > bounds.startKey ? startKey : bounds.startKey}T00:00:00Z`);
  const end = new Date(`${endKey < bounds.endKey ? endKey : bounds.endKey}T00:00:00Z`);
  if (start > end) return 0;
  let days = 0;
  for (const cursor = new Date(start); cursor <= end; cursor.setUTCDate(cursor.getUTCDate() + 1)) {
    const day = cursor.getUTCDay();
    if (day !== 0 && day !== 6) days += 1;
  }
  return days;
}

exports.setSalaryProfile = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!PAYROLL_ADMIN_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "Only Company Owner or HR can manage salary profiles.");
    }
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(request.data?.employeeId, "employeeId");
    const employeeRef = db.collection("companies").doc(companyId).collection("employees").doc(employeeId);
    const employee = (await employeeRef.get()).data();
    if (!employee) throw new HttpsError("not-found", "Employee was not found.");

    const profile = {
      employeeId,
      basicSalary: payrollMoney(request.data?.basicSalary, "basicSalary"),
      fixedAllowance: payrollMoney(request.data?.fixedAllowance, "fixedAllowance"),
      fixedDeduction: payrollMoney(request.data?.fixedDeduction, "fixedDeduction"),
      epfEmployee: payrollMoney(request.data?.epfEmployee, "epfEmployee"),
      socsoEmployee: payrollMoney(request.data?.socsoEmployee, "socsoEmployee"),
      eisEmployee: payrollMoney(request.data?.eisEmployee, "eisEmployee"),
      currency: "MYR",
      updatedBy: request.auth.uid,
      updatedAt: FieldValue.serverTimestamp(),
    };
    await db.collection("companies").doc(companyId).collection("salaryProfiles").doc(employeeId).set(profile, {merge: true});
    return {employeeId};
  },
);

exports.generatePayrollDraft = onCall(
  {enforceAppCheck: false, timeoutSeconds: 120},
  async (request) => {
    const caller = await loadCaller(request);
    if (!PAYROLL_ADMIN_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "Only Company Owner or HR can generate payroll.");
    }
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const month = payrollMonth(request.data?.month);
    const companyRef = db.collection("companies").doc(companyId);
    const runRef = companyRef.collection("payrollRuns").doc(month);
    const existing = (await runRef.get()).data();
    if (existing?.status === "finalized") {
      throw new HttpsError("failed-precondition", "Finalized payroll cannot be regenerated.");
    }

    const [employeesSnap, profilesSnap, claimsSnap, leaveSnap] = await Promise.all([
      companyRef.collection("employees").where("employmentStatus", "==", "active").get(),
      companyRef.collection("salaryProfiles").get(),
      companyRef.collection("claimRequests").where("status", "==", "approved").get(),
      companyRef.collection("leaveRequests").where("status", "==", "approved").where("typeId", "==", "unpaid").get(),
    ]);

    const profiles = new Map(profilesSnap.docs.map((doc) => [doc.id, doc.data()]));
    const bounds = monthBounds(month);
    const batch = db.batch();
    let totalNet = 0;
    let employeeCount = 0;

    for (const employeeDoc of employeesSnap.docs) {
      const employee = employeeDoc.data();
      const employeeId = employeeDoc.id;
      const profile = profiles.get(employeeId);
      if (!profile || Number(profile.basicSalary ?? 0) <= 0) continue;

      const basicSalary = Number(profile.basicSalary ?? 0);
      const allowance = Number(profile.fixedAllowance ?? 0);
      const otherDeduction = Number(profile.fixedDeduction ?? 0);
      const epfEmployee = Number(profile.epfEmployee ?? 0);
      const socsoEmployee = Number(profile.socsoEmployee ?? 0);
      const eisEmployee = Number(profile.eisEmployee ?? 0);

      const employeeClaims = claimsSnap.docs.filter((doc) => {
        const data = doc.data();
        return data.employeeId === employeeId &&
          data.expenseDateKey >= bounds.startKey &&
          data.expenseDateKey <= bounds.endKey;
      });
      const claimReimbursement = employeeClaims.reduce(
        (sum, doc) => sum + Number(doc.data().amount ?? 0), 0,
      );

      let unpaidDays = 0;
      for (const doc of leaveSnap.docs) {
        const leave = doc.data();
        if (leave.employeeId !== employeeId) continue;
        const overlap = weekdaysBetween(leave.startDateKey, leave.endDateKey, month);
        if (overlap <= 0) continue;
        if (leave.duration === "halfDayMorning" || leave.duration === "halfDayAfternoon") {
          unpaidDays += 0.5;
        } else {
          unpaidDays += overlap;
        }
      }

      // Foundation policy: 26-day salary divisor. Kept explicit in the
      // generated payslip so a later payroll-policy module can replace it.
      const salaryDivisor = 26;
      const unpaidLeaveDeduction = Math.round((basicSalary / salaryDivisor) * unpaidDays * 100) / 100;
      const grossPay = Math.round((basicSalary + allowance + claimReimbursement) * 100) / 100;
      const totalDeduction = Math.round(
        (otherDeduction + epfEmployee + socsoEmployee + eisEmployee + unpaidLeaveDeduction) * 100,
      ) / 100;
      const netPay = Math.max(0, Math.round((grossPay - totalDeduction) * 100) / 100);
      const payslipId = `${month}_${employeeId}`;

      batch.set(companyRef.collection("payslips").doc(payslipId), {
        companyId,
        month,
        employeeId,
        employeeName: employee.displayName || employee.name || employeeId,
        department: employee.department || "",
        currency: "MYR",
        basicSalary,
        allowance,
        claimReimbursement,
        claimIds: employeeClaims.map((doc) => doc.id),
        unpaidLeaveDays: unpaidDays,
        unpaidLeaveDeduction,
        salaryDivisor,
        otherDeduction,
        epfEmployee,
        socsoEmployee,
        eisEmployee,
        grossPay,
        totalDeduction,
        netPay,
        status: "draft",
        generatedAt: FieldValue.serverTimestamp(),
        generatedBy: request.auth.uid,
        finalizedAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      totalNet += netPay;
      employeeCount += 1;
    }

    batch.set(runRef, {
      companyId,
      month,
      status: "draft",
      employeeCount,
      totalNetPay: Math.round(totalNet * 100) / 100,
      generatedBy: request.auth.uid,
      generatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await batch.commit();
    return {month, employeeCount, totalNetPay: Math.round(totalNet * 100) / 100};
  },
);

exports.finalizePayroll = onCall(
  {enforceAppCheck: false, timeoutSeconds: 120},
  async (request) => {
    const caller = await loadCaller(request);
    if (!PAYROLL_ADMIN_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "Only Company Owner or HR can finalize payroll.");
    }
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const month = payrollMonth(request.data?.month);
    const companyRef = db.collection("companies").doc(companyId);
    const runRef = companyRef.collection("payrollRuns").doc(month);
    const run = (await runRef.get()).data();
    if (!run || run.status !== "draft") {
      throw new HttpsError("failed-precondition", "Generate a payroll draft before finalizing.");
    }

    const payslipsSnap = await companyRef.collection("payslips").where("month", "==", month).get();
    if (payslipsSnap.empty) {
      throw new HttpsError("failed-precondition", "This payroll draft has no payslips.");
    }

    const batch = db.batch();
    const claimIds = new Set();
    for (const doc of payslipsSnap.docs) {
      const data = doc.data();
      for (const claimId of data.claimIds || []) claimIds.add(claimId);
      batch.update(doc.ref, {
        status: "finalized",
        finalizedAt: FieldValue.serverTimestamp(),
        finalizedBy: request.auth.uid,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    for (const claimId of claimIds) {
      batch.update(companyRef.collection("claimRequests").doc(claimId), {
        status: "paid",
        paidAt: FieldValue.serverTimestamp(),
        paidBy: request.auth.uid,
        paymentReference: `PAYROLL-${month}`,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    batch.update(runRef, {
      status: "finalized",
      finalizedAt: FieldValue.serverTimestamp(),
      finalizedBy: request.auth.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "payroll",
      action: "finalizePayroll",
      targetType: "payrollRun",
      targetId: month,
      summary: `Finalized payroll for ${month}.`,
    });
    return {month, status: "finalized"};
  },
);


const REPORT_ROLES = new Set([
  "companyOwner",
  "hrAdmin",
  "manager",
]);

exports.getMonthlyHrReport = onCall(
  {enforceAppCheck: false, timeoutSeconds: 60},
  async (request) => {
    const caller = await loadCaller(request);
    if (!REPORT_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to view HR reports.",
      );
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const month = asNonEmptyString(request.data?.month, "month");
    if (!/^\d{4}-\d{2}$/.test(month)) {
      throw new HttpsError(
        "invalid-argument",
        "Report month must use YYYY-MM.",
      );
    }

    const monthNumber = Number(month.slice(5));
    if (monthNumber < 1 || monthNumber > 12) {
      throw new HttpsError("invalid-argument", "Report month is invalid.");
    }

    const [year, numericMonth] = month.split("-").map(Number);
    const start = new Date(Date.UTC(year, numericMonth - 1, 1));
    const end = new Date(Date.UTC(year, numericMonth, 0));
    const startKey = start.toISOString().slice(0, 10);
    const endKey = end.toISOString().slice(0, 10);
    const companyRef = db.collection("companies").doc(companyId);

    const [
      employeesSnapshot,
      attendanceSnapshot,
      leaveSnapshot,
      claimsSnapshot,
      payrollRunSnapshot,
    ] = await Promise.all([
      companyRef
        .collection("employees")
        .where("employmentStatus", "==", "active")
        .get(),
      companyRef
        .collection("attendance")
        .where("dateKey", ">=", startKey)
        .where("dateKey", "<=", endKey)
        .get(),
      companyRef.collection("leaveRequests").get(),
      companyRef.collection("claimRequests").get(),
      companyRef.collection("payrollRuns").doc(month).get(),
    ]);

    const attendance = attendanceSnapshot.docs.map((doc) => doc.data());
    const presentEmployees = new Set(
      attendance.map((item) => item.employeeId).filter(Boolean),
    ).size;
    const lateRecords = attendance.filter(
      (item) => item.clockInStatus === "late" || item.isLate === true,
    ).length;
    const earlyLeaveRecords = attendance.filter(
      (item) => item.clockOutStatus === "early" || item.leftEarly === true,
    ).length;
    const completedAttendanceRecords = attendance.filter(
      (item) => item.clockInAt && item.clockOutAt,
    ).length;

    const leaves = leaveSnapshot.docs.map((doc) => doc.data());
    const monthLeaves = leaves.filter((item) =>
      String(item.startDateKey || "") <= endKey &&
      String(item.endDateKey || "") >= startKey
    );
    const approvedLeaves = monthLeaves.filter(
      (item) => item.status === "approved",
    );
    const pendingLeaveRequests = monthLeaves.filter(
      (item) => item.status === "pending",
    ).length;

    let approvedLeaveDays = 0;
    for (const leave of approvedLeaves) {
      if (leave.startDateKey >= startKey && leave.endDateKey <= endKey) {
        approvedLeaveDays += Number(leave.daysRequested || 0);
        continue;
      }

      let cursor = new Date(
        `${leave.startDateKey > startKey ? leave.startDateKey : startKey}T00:00:00Z`,
      );
      const leaveEnd = new Date(
        `${leave.endDateKey < endKey ? leave.endDateKey : endKey}T00:00:00Z`,
      );
      let overlapDays = 0;
      while (cursor <= leaveEnd) {
        const weekday = cursor.getUTCDay();
        if (weekday !== 0 && weekday !== 6) overlapDays += 1;
        cursor.setUTCDate(cursor.getUTCDate() + 1);
      }
      if (
        leave.duration === "halfDayMorning" ||
        leave.duration === "halfDayAfternoon"
      ) {
        overlapDays = 0.5;
      }
      approvedLeaveDays += overlapDays;
    }

    const claims = claimsSnapshot.docs
      .map((doc) => doc.data())
      .filter((item) =>
        String(item.expenseDateKey || "") >= startKey &&
        String(item.expenseDateKey || "") <= endKey
      );
    const pendingClaimCount = claims.filter(
      (item) => item.status === "pending",
    ).length;
    const approvedClaimCount = claims.filter(
      (item) => item.status === "approved",
    ).length;
    const paidClaimCount = claims.filter(
      (item) => item.status === "paid",
    ).length;
    const claimAmount = claims.reduce(
      (sum, item) => sum + Number(item.amount || 0),
      0,
    );

    const payrollVisible =
      caller.role === "companyOwner" ||
      caller.role === "hrAdmin";
    const payroll = payrollRunSnapshot.data() || {};

    return {
      month,
      activeEmployees: employeesSnapshot.size,
      attendanceRecords: attendance.length,
      presentEmployees,
      lateRecords,
      earlyLeaveRecords,
      completedAttendanceRecords,
      approvedLeaveRequests: approvedLeaves.length,
      approvedLeaveDays: Math.round(approvedLeaveDays * 10) / 10,
      pendingLeaveRequests,
      claimCount: claims.length,
      pendingClaimCount,
      approvedClaimCount,
      paidClaimCount,
      claimAmount: Math.round(claimAmount * 100) / 100,
      payrollVisible,
      payrollStatus: payrollVisible ? (payroll.status || null) : null,
      payrollEmployeeCount: payrollVisible ?
        Number(payroll.employeeCount || 0) :
        0,
      totalNetPay: payrollVisible ?
        Number(payroll.totalNetPay || 0) :
        0,
    };
  },
);


const WORKFORCE_APPROVER_ROLES = new Set([
  "companyOwner",
  "hrAdmin",
  "manager",
]);
const WORKFORCE_ADMIN_ROLES = new Set(["companyOwner", "hrAdmin"]);

function workforceDateKey(value, fieldName = "dateKey") {
  const raw = asNonEmptyString(value, fieldName);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new HttpsError("invalid-argument", `${fieldName} must use YYYY-MM-DD.`);
  }
  const date = new Date(`${raw}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }
  return raw;
}

exports.getWorkforceTimeOverview = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const month = asNonEmptyString(request.data?.month, "month");
    if (!/^\d{4}-\d{2}$/.test(month)) {
      throw new HttpsError("invalid-argument", "Month must use YYYY-MM.");
    }

    const startKey = `${month}-01`;
    const [year, monthNumber] = month.split("-").map(Number);
    const endKey = new Date(Date.UTC(year, monthNumber, 0))
      .toISOString()
      .slice(0, 10);
    const companyRef = db.collection("companies").doc(companyId);

    const [holidaysSnap, shiftsSnap, overtimeSnap] = await Promise.all([
      companyRef
        .collection("holidays")
        .where("dateKey", ">=", startKey)
        .where("dateKey", "<=", endKey)
        .get(),
      companyRef
        .collection("employeeShifts")
        .where("dateKey", ">=", startKey)
        .where("dateKey", "<=", endKey)
        .get(),
      companyRef
        .collection("overtimeRequests")
        .where("dateKey", ">=", startKey)
        .where("dateKey", "<=", endKey)
        .get(),
    ]);

    const management = WORKFORCE_APPROVER_ROLES.has(caller.role);
    const employeeId = caller.employeeId;

    return {
      month,
      holidays: holidaysSnap.docs.map((doc) => ({id: doc.id, ...doc.data()})),
      shifts: shiftsSnap.docs
        .map((doc) => ({id: doc.id, ...doc.data()}))
        .filter((item) => management || item.employeeId === employeeId),
      overtime: overtimeSnap.docs
        .map((doc) => ({id: doc.id, ...doc.data()}))
        .filter((item) => management || item.employeeId === employeeId),
    };
  },
);

exports.upsertCompanyHoliday = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!WORKFORCE_ADMIN_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "Only Company Owner or HR can manage holidays.",
      );
    }
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const dateKey = workforceDateKey(request.data?.dateKey);
    const name = asNonEmptyString(request.data?.name, "name").slice(0, 120);
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("holidays")
      .doc(dateKey);

    await ref.set({
      companyId,
      dateKey,
      name,
      isPaid: request.data?.isPaid !== false,
      updatedBy: request.auth.uid,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    return {id: dateKey};
  },
);

exports.assignEmployeeShift = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!WORKFORCE_APPROVER_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "You cannot assign shifts.");
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(request.data?.employeeId, "employeeId");
    const dateKey = workforceDateKey(request.data?.dateKey);
    const shiftName = asNonEmptyString(request.data?.shiftName, "shiftName")
      .slice(0, 80);
    const startMinutes = Number(request.data?.startMinutes);
    const endMinutes = Number(request.data?.endMinutes);

    if (
      !Number.isInteger(startMinutes) ||
      !Number.isInteger(endMinutes) ||
      startMinutes < 0 ||
      startMinutes > 1439 ||
      endMinutes < 0 ||
      endMinutes > 1439
    ) {
      throw new HttpsError("invalid-argument", "Shift times are invalid.");
    }

    const employeeRef = db
      .collection("companies")
      .doc(companyId)
      .collection("employees")
      .doc(employeeId);
    const employee = (await employeeRef.get()).data();
    if (!employee) {
      throw new HttpsError("not-found", "Employee was not found.");
    }

    const id = `${dateKey}_${employeeId}`;
    await db
      .collection("companies")
      .doc(companyId)
      .collection("employeeShifts")
      .doc(id)
      .set({
        companyId,
        employeeId,
        employeeName: employee.displayName || employee.name || employeeId,
        dateKey,
        shiftName,
        startMinutes,
        endMinutes,
        assignedBy: request.auth.uid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

    return {id};
  },
);

exports.submitOvertimeRequest = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const dateKey = workforceDateKey(request.data?.dateKey);
    const minutes = Number(request.data?.minutes);
    const reason = asNonEmptyString(request.data?.reason, "reason").slice(0, 1000);

    if (!Number.isInteger(minutes) || minutes < 30 || minutes > 720) {
      throw new HttpsError(
        "invalid-argument",
        "Overtime must be between 30 minutes and 12 hours.",
      );
    }

    const employee = (
      await db
        .collection("companies")
        .doc(companyId)
        .collection("employees")
        .doc(employeeId)
        .get()
    ).data();

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("overtimeRequests")
      .doc();

    await ref.set({
      companyId,
      employeeId,
      employeeName: employee?.displayName || caller.displayName || employeeId,
      dateKey,
      minutes,
      reason,
      status: "pending",
      submittedBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      reviewedAt: null,
      reviewerId: null,
      reviewNote: null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {id: ref.id, status: "pending"};
  },
);

exports.reviewOvertimeRequest = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!WORKFORCE_APPROVER_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "You cannot review overtime.");
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const requestId = asNonEmptyString(request.data?.requestId, "requestId");
    const decision = asNonEmptyString(request.data?.decision, "decision");
    const note = typeof request.data?.note === "string" ?
      request.data.note.trim().slice(0, 1000) :
      "";

    if (!["approved", "rejected"].includes(decision)) {
      throw new HttpsError(
        "invalid-argument",
        "Decision must be approved or rejected.",
      );
    }

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("overtimeRequests")
      .doc(requestId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const overtime = snapshot.data();
      if (!overtime) {
        throw new HttpsError("not-found", "Overtime request was not found.");
      }
      if (overtime.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "This overtime request has already been reviewed.",
        );
      }
      if (overtime.submittedBy === request.auth.uid) {
        throw new HttpsError(
          "permission-denied",
          "You cannot review your own overtime request.",
        );
      }

      transaction.update(ref, {
        status: decision,
        reviewerId: request.auth.uid,
        reviewerName: caller.displayName || caller.employeeId || "Reviewer",
        reviewNote: note || null,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "workforce",
      action: "reviewOvertimeRequest",
      targetType: "overtimeRequest",
      targetId: requestId,
      summary: `Reviewed overtime request ${requestId}: ${decision}.`,
    });
    return {status: decision};
  },
);


const EMPLOYEE_DOCUMENT_CATEGORIES = new Set([
  "IC / Passport",
  "Offer Letter",
  "Contract",
  "Certificate",
  "Medical",
  "Other",
]);

exports.registerEmployeeDocument = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(request.data?.employeeId, "employeeId");
    const category = asNonEmptyString(request.data?.category, "category");
    const fileName = asNonEmptyString(request.data?.fileName, "fileName").slice(0, 240);
    const storagePath = asNonEmptyString(request.data?.storagePath, "storagePath");
    const contentType = asNonEmptyString(request.data?.contentType, "contentType");
    const sizeBytes = Number(request.data?.sizeBytes);
    const expiryDateKey =
      typeof request.data?.expiryDateKey === "string" &&
      request.data.expiryDateKey.trim().length > 0 ?
        request.data.expiryDateKey.trim() :
        null;
    const notes =
      typeof request.data?.notes === "string" ?
        request.data.notes.trim().slice(0, 1000) :
        null;

    const management = ["companyOwner", "hrAdmin"].includes(caller.role);
    if (!management && employeeId !== caller.employeeId) {
      throw new HttpsError(
        "permission-denied",
        "You cannot register a document for another employee.",
      );
    }
    if (!EMPLOYEE_DOCUMENT_CATEGORIES.has(category)) {
      throw new HttpsError("invalid-argument", "Document category is invalid.");
    }
    if (!Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > 15 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "Document size is invalid.");
    }
    if (!["application/pdf", "image/jpeg", "image/png"].includes(contentType)) {
      throw new HttpsError("invalid-argument", "Unsupported document type.");
    }
    if (
      !storagePath.startsWith(
        `companies/${companyId}/employee_documents/${employeeId}/`,
      )
    ) {
      throw new HttpsError(
        "permission-denied",
        "Document path does not belong to this employee.",
      );
    }
    if (expiryDateKey && !/^\d{4}-\d{2}-\d{2}$/.test(expiryDateKey)) {
      throw new HttpsError("invalid-argument", "Expiry date is invalid.");
    }

    const employeeRef = db
      .collection("companies")
      .doc(companyId)
      .collection("employees")
      .doc(employeeId);
    const employee = (await employeeRef.get()).data();
    if (!employee) {
      throw new HttpsError("not-found", "Employee was not found.");
    }

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("employeeDocuments")
      .doc();

    await ref.set({
      companyId,
      employeeId,
      employeeName: employee.displayName || employee.name || employeeId,
      category,
      fileName,
      storagePath,
      contentType,
      sizeBytes,
      expiryDateKey,
      notes: notes || null,
      uploadedBy: request.auth.uid,
      uploadedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (expiryDateKey) {
      const identity = await db
        .collection("identities")
        .where("companyId", "==", companyId)
        .where("employeeId", "==", employeeId)
        .limit(1)
        .get();
      if (!identity.empty) {
        await createUserNotification({
          companyId,
          uid: identity.docs[0].id,
          type: "general",
          title: "Document expiry recorded",
          body: `${fileName} expires on ${expiryDateKey}.`,
          targetType: "employeeDocument",
          targetId: ref.id,
        });
      }
    }

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "documents",
      action: "registerEmployeeDocument",
      targetType: "employeeDocument",
      targetId: ref.id,
      summary: `Registered employee document for ${employeeId}.`,
    });
    return {documentId: ref.id};
  },
);

exports.deleteEmployeeDocument = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const documentId = asNonEmptyString(request.data?.documentId, "documentId");
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("employeeDocuments")
      .doc(documentId);
    const snapshot = await ref.get();
    const document = snapshot.data();
    if (!document) {
      throw new HttpsError("not-found", "Document was not found.");
    }

    const management = ["companyOwner", "hrAdmin"].includes(caller.role);
    if (!management && document.employeeId !== caller.employeeId) {
      throw new HttpsError("permission-denied", "You cannot delete this document.");
    }

    await ref.delete();
    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "documents",
      action: "deleteEmployeeDocument",
      targetType: "employeeDocument",
      targetId: documentId,
      summary: `Deleted employee document ${documentId}.`,
    });
    return {deleted: true};
  },
);


const PERFORMANCE_REVIEWER_ROLES = new Set([
  "companyOwner",
  "hrAdmin",
  "manager",
]);

function performancePeriod(value) {
  const period = asNonEmptyString(value, "period");
  if (!/^\d{4}$/.test(period)) {
    throw new HttpsError("invalid-argument", "Performance period must be a year.");
  }
  return period;
}

function performanceRating(value, fieldName = "rating") {
  const rating = Number(value);
  if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be between 1 and 5.`,
    );
  }
  return Math.round(rating * 10) / 10;
}

async function performanceIdentityUid(companyId, employeeId) {
  const snapshot = await db
    .collection("identities")
    .where("companyId", "==", companyId)
    .where("employeeId", "==", employeeId)
    .limit(1)
    .get();
  return snapshot.empty ? null : snapshot.docs[0].id;
}

exports.getPerformanceOverview = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const period = performancePeriod(request.data?.period);
    const canManage = PERFORMANCE_REVIEWER_ROLES.has(caller.role);

    let query = db
      .collection("companies")
      .doc(companyId)
      .collection("performanceReviews")
      .where("period", "==", period);

    if (!canManage) {
      query = query.where("employeeId", "==", employeeId);
    }

    const snapshot = await query.get();
    const reviews = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      period,
      canManage,
      currentEmployeeId: employeeId,
      reviews,
    };
  },
);

exports.ensurePerformanceReview = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const callerEmployeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const period = performancePeriod(request.data?.period);
    const requestedEmployeeId =
      typeof request.data?.employeeId === "string" &&
      request.data.employeeId.trim().length > 0 ?
        request.data.employeeId.trim() :
        callerEmployeeId;

    if (
      requestedEmployeeId !== callerEmployeeId &&
      !PERFORMANCE_REVIEWER_ROLES.has(caller.role)
    ) {
      throw new HttpsError(
        "permission-denied",
        "You cannot start a review for another employee.",
      );
    }

    const employeeRef = db
      .collection("companies")
      .doc(companyId)
      .collection("employees")
      .doc(requestedEmployeeId);
    const employee = (await employeeRef.get()).data();
    if (!employee) {
      throw new HttpsError("not-found", "Employee was not found.");
    }

    const id = `${period}_${requestedEmployeeId}`;
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("performanceReviews")
      .doc(id);

    const existing = await ref.get();
    if (!existing.exists) {
      await ref.set({
        companyId,
        period,
        employeeId: requestedEmployeeId,
        employeeName:
          employee.displayName || employee.name || requestedEmployeeId,
        department: employee.department || "",
        status: "goalSetting",
        goals: [],
        selfRating: null,
        selfComment: null,
        managerRating: null,
        managerComment: null,
        createdBy: request.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    return {reviewId: id};
  },
);

exports.upsertPerformanceGoal = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const reviewId = asNonEmptyString(request.data?.reviewId, "reviewId");
    const title = asNonEmptyString(request.data?.title, "title").slice(0, 160);
    const description =
      typeof request.data?.description === "string" ?
        request.data.description.trim().slice(0, 1500) :
        "";
    const weight = Number(request.data?.weight);
    const progress = Number(request.data?.progress);
    const goalId =
      typeof request.data?.goalId === "string" &&
      request.data.goalId.trim().length > 0 ?
        request.data.goalId.trim() :
        crypto.randomUUID();

    if (!Number.isFinite(weight) || weight <= 0 || weight > 100) {
      throw new HttpsError(
        "invalid-argument",
        "Goal weight must be between 0 and 100.",
      );
    }
    if (!Number.isFinite(progress) || progress < 0 || progress > 100) {
      throw new HttpsError(
        "invalid-argument",
        "Goal progress must be between 0 and 100.",
      );
    }

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("performanceReviews")
      .doc(reviewId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const review = snapshot.data();
      if (!review) {
        throw new HttpsError("not-found", "Performance review was not found.");
      }

      const isOwner = review.employeeId === caller.employeeId;
      const canManage = PERFORMANCE_REVIEWER_ROLES.has(caller.role);
      if (!isOwner && !canManage) {
        throw new HttpsError(
          "permission-denied",
          "You cannot edit this performance review.",
        );
      }
      if (!["goalSetting", "selfReview"].includes(review.status)) {
        throw new HttpsError(
          "failed-precondition",
          "Goals can no longer be changed in this review.",
        );
      }

      const goals = Array.isArray(review.goals) ? [...review.goals] : [];
      const index = goals.findIndex((goal) => goal.id === goalId);
      const updatedGoal = {
        id: goalId,
        title,
        description,
        weight: Math.round(weight * 10) / 10,
        progress: Math.round(progress * 10) / 10,
        selfRating: index >= 0 ? goals[index].selfRating || null : null,
        managerRating: index >= 0 ? goals[index].managerRating || null : null,
      };

      if (index >= 0) {
        goals[index] = updatedGoal;
      } else {
        goals.push(updatedGoal);
      }

      const totalWeight = goals.reduce(
        (sum, goal) => sum + Number(goal.weight || 0),
        0,
      );
      if (totalWeight > 100.001) {
        throw new HttpsError(
          "invalid-argument",
          "Total KPI / Goal weight cannot exceed 100%.",
        );
      }

      transaction.update(ref, {
        goals,
        status: "selfReview",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {goalId};
  },
);

exports.submitPerformanceSelfReview = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const reviewId = asNonEmptyString(request.data?.reviewId, "reviewId");
    const rating = performanceRating(request.data?.rating);
    const comment =
      typeof request.data?.comment === "string" ?
        request.data.comment.trim().slice(0, 2500) :
        "";

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("performanceReviews")
      .doc(reviewId);

    let employeeName = "Employee";
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const review = snapshot.data();
      if (!review) {
        throw new HttpsError("not-found", "Performance review was not found.");
      }
      if (review.employeeId !== caller.employeeId) {
        throw new HttpsError(
          "permission-denied",
          "You can submit only your own self review.",
        );
      }
      if (!Array.isArray(review.goals) || review.goals.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "Add at least one KPI / Goal before submitting.",
        );
      }
      if (review.status === "completed") {
        throw new HttpsError(
          "failed-precondition",
          "This performance review is already completed.",
        );
      }

      employeeName = review.employeeName || caller.employeeId;
      transaction.update(ref, {
        selfRating: rating,
        selfComment: comment || null,
        status: "managerReview",
        selfReviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const reviewers = await notificationRecipientsForRoles(
      companyId,
      ["companyOwner", "hrAdmin", "manager"],
    );
    for (const uid of reviewers) {
      if (uid === request.auth.uid) continue;
      await createUserNotification({
        companyId,
        uid,
        type: "general",
        title: "Performance review ready",
        body: `${employeeName} submitted a self review.`,
        targetType: "performanceReview",
        targetId: reviewId,
      });
    }

    return {status: "managerReview"};
  },
);

exports.finalizePerformanceReview = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!PERFORMANCE_REVIEWER_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to finalize reviews.",
      );
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const reviewId = asNonEmptyString(request.data?.reviewId, "reviewId");
    const rating = performanceRating(request.data?.rating);
    const comment =
      typeof request.data?.comment === "string" ?
        request.data.comment.trim().slice(0, 2500) :
        "";

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("performanceReviews")
      .doc(reviewId);

    let employeeId = null;
    let employeeName = "Employee";

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const review = snapshot.data();
      if (!review) {
        throw new HttpsError("not-found", "Performance review was not found.");
      }
      if (review.employeeId === caller.employeeId) {
        throw new HttpsError(
          "permission-denied",
          "You cannot finalize your own performance review.",
        );
      }
      if (review.status !== "managerReview") {
        throw new HttpsError(
          "failed-precondition",
          "The employee must submit a self review first.",
        );
      }

      employeeId = review.employeeId;
      employeeName = review.employeeName || review.employeeId;

      transaction.update(ref, {
        managerRating: rating,
        managerComment: comment || null,
        status: "completed",
        reviewedBy: request.auth.uid,
        reviewedByName: caller.displayName || caller.employeeId || "Reviewer",
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const employeeUid = await performanceIdentityUid(companyId, employeeId);
    if (employeeUid) {
      await createUserNotification({
        companyId,
        uid: employeeUid,
        type: "general",
        title: "Performance review completed",
        body: `${employeeName}, your performance review has been finalized.`,
        targetType: "performanceReview",
        targetId: reviewId,
      });
    }

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "performance",
      action: "finalizePerformanceReview",
      targetType: "performanceReview",
      targetId: reviewId,
      summary: `Finalized performance review for ${employeeName}.`,
    });
    return {status: "completed"};
  },
);


const LIFECYCLE_MANAGEMENT_ROLES = new Set(["companyOwner", "hrAdmin"]);

const ONBOARDING_TASKS = [
  {id: "profile", title: "Confirm personal profile", category: "Employee", employeeCanComplete: true},
  {id: "documents", title: "Upload required employee documents", category: "Documents", employeeCanComplete: true},
  {id: "policy", title: "Acknowledge company policies", category: "Compliance", employeeCanComplete: true},
  {id: "assignment", title: "Confirm department, position and manager", category: "HR", employeeCanComplete: false},
  {id: "access", title: "Provision work access and accounts", category: "IT / HR", employeeCanComplete: false},
  {id: "orientation", title: "Complete orientation", category: "HR", employeeCanComplete: true},
];

const OFFBOARDING_TASKS = [
  {id: "handover", title: "Complete work handover", category: "Employee", employeeCanComplete: true},
  {id: "assets", title: "Return company assets", category: "Assets", employeeCanComplete: false},
  {id: "claims", title: "Clear outstanding claims and payroll items", category: "Finance", employeeCanComplete: false},
  {id: "exit", title: "Complete exit interview / acknowledgement", category: "HR", employeeCanComplete: true},
  {id: "access", title: "Revoke company system access", category: "IT / HR", employeeCanComplete: false},
];

function lifecycleDate(value, fieldName) {
  const date = asNonEmptyString(value, fieldName);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }
  return date;
}

async function lifecycleEmployee(companyId, employeeId) {
  const ref = db
    .collection("companies")
    .doc(companyId)
    .collection("employees")
    .doc(employeeId);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "Employee was not found.");
  }
  return {ref, data: snapshot.data()};
}

exports.getEmployeeLifecycleOverview = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const canManage = LIFECYCLE_MANAGEMENT_ROLES.has(caller.role);

    let query = db
      .collection("companies")
      .doc(companyId)
      .collection("employeeLifecycle");

    if (!canManage) {
      query = query.where("employeeId", "==", employeeId);
    }

    const snapshot = await query.limit(200).get();
    const cases = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {canManage, currentEmployeeId: employeeId, cases};
  },
);

exports.startEmployeeOnboarding = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!LIFECYCLE_MANAGEMENT_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "HR access is required.");
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(request.data?.employeeId, "employeeId");
    const startDateKey = lifecycleDate(request.data?.startDateKey, "startDateKey");
    const probationEndDateKey =
      typeof request.data?.probationEndDateKey === "string" &&
      request.data.probationEndDateKey.trim().length > 0 ?
        lifecycleDate(request.data.probationEndDateKey, "probationEndDateKey") :
        null;

    const employee = await lifecycleEmployee(companyId, employeeId);
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("employeeLifecycle")
      .doc(`onboarding_${employeeId}_${startDateKey}`);

    await ref.set({
      companyId,
      employeeId,
      employeeName:
        employee.data.displayName || employee.data.name || employeeId,
      type: "onboarding",
      status: "active",
      startDateKey,
      endDateKey: null,
      probationEndDateKey,
      reason: null,
      tasks: ONBOARDING_TASKS.map((task) => ({...task, completed: false})),
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: false});

    const uid = await performanceIdentityUid(companyId, employeeId);
    if (uid) {
      await createUserNotification({
        companyId,
        uid,
        type: "general",
        title: "Onboarding started",
        body: "Your onboarding checklist is ready.",
        targetType: "employeeLifecycle",
        targetId: ref.id,
      });
    }

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "lifecycle",
      action: "startOnboarding",
      targetType: "employee",
      targetId: employeeId,
      summary: `Started onboarding for ${employeeId}.`,
    });
    return {caseId: ref.id};
  },
);

exports.startEmployeeOffboarding = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!LIFECYCLE_MANAGEMENT_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "HR access is required.");
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(request.data?.employeeId, "employeeId");
    if (employeeId === caller.employeeId) {
      throw new HttpsError(
        "permission-denied",
        "You cannot offboard your own account.",
      );
    }

    const lastWorkingDateKey = lifecycleDate(
      request.data?.lastWorkingDateKey,
      "lastWorkingDateKey",
    );
    const reason = asNonEmptyString(request.data?.reason, "reason").slice(0, 1000);
    const employee = await lifecycleEmployee(companyId, employeeId);
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("employeeLifecycle")
      .doc(`offboarding_${employeeId}_${lastWorkingDateKey}`);

    await ref.set({
      companyId,
      employeeId,
      employeeName:
        employee.data.displayName || employee.data.name || employeeId,
      type: "offboarding",
      status: "active",
      startDateKey: null,
      endDateKey: lastWorkingDateKey,
      probationEndDateKey: null,
      reason,
      tasks: OFFBOARDING_TASKS.map((task) => ({...task, completed: false})),
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: false});

    const uid = await performanceIdentityUid(companyId, employeeId);
    if (uid) {
      await createUserNotification({
        companyId,
        uid,
        type: "general",
        title: "Offboarding workflow started",
        body: `Your recorded last working day is ${lastWorkingDateKey}.`,
        targetType: "employeeLifecycle",
        targetId: ref.id,
      });
    }

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "lifecycle",
      action: "startOffboarding",
      targetType: "employee",
      targetId: employeeId,
      summary: `Started offboarding for ${employeeId}.`,
    });
    return {caseId: ref.id};
  },
);

exports.updateLifecycleTask = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const caseId = asNonEmptyString(request.data?.caseId, "caseId");
    const taskId = asNonEmptyString(request.data?.taskId, "taskId");
    const completed = request.data?.completed === true;
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("employeeLifecycle")
      .doc(caseId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const item = snapshot.data();
      if (!item) {
        throw new HttpsError("not-found", "Lifecycle case was not found.");
      }
      if (item.status !== "active") {
        throw new HttpsError("failed-precondition", "This workflow is closed.");
      }

      const management = LIFECYCLE_MANAGEMENT_ROLES.has(caller.role);
      const ownCase = item.employeeId === caller.employeeId;
      const tasks = Array.isArray(item.tasks) ? [...item.tasks] : [];
      const index = tasks.findIndex((task) => task.id === taskId);
      if (index < 0) {
        throw new HttpsError("not-found", "Checklist task was not found.");
      }
      if (!management && (!ownCase || tasks[index].employeeCanComplete !== true)) {
        throw new HttpsError(
          "permission-denied",
          "You cannot update this checklist task.",
        );
      }

      tasks[index] = {
        ...tasks[index],
        completed,
        completedBy: completed ? request.auth.uid : null,
      };
      transaction.update(ref, {
        tasks,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {updated: true};
  },
);

exports.completeEmployeeLifecycle = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!LIFECYCLE_MANAGEMENT_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "HR access is required.");
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const caseId = asNonEmptyString(request.data?.caseId, "caseId");
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("employeeLifecycle")
      .doc(caseId);

    let item;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      item = snapshot.data();
      if (!item) {
        throw new HttpsError("not-found", "Lifecycle case was not found.");
      }
      const tasks = Array.isArray(item.tasks) ? item.tasks : [];
      if (tasks.length === 0 || tasks.some((task) => task.completed !== true)) {
        throw new HttpsError(
          "failed-precondition",
          "Complete every checklist task first.",
        );
      }

      if (item.type === "offboarding") {
        const assignedAssets = await db
          .collection("companies")
          .doc(companyId)
          .collection("assets")
          .where("assignedEmployeeId", "==", item.employeeId)
          .where("status", "==", "assigned")
          .limit(1)
          .get();
        if (!assignedAssets.empty) {
          throw new HttpsError(
            "failed-precondition",
            "Return all company assets before completing offboarding.",
          );
        }
      }

      transaction.update(ref, {
        status: "completed",
        completedBy: request.auth.uid,
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      const employeeRef = db
        .collection("companies")
        .doc(companyId)
        .collection("employees")
        .doc(item.employeeId);

      if (item.type === "onboarding") {
        transaction.set(employeeRef, {
          lifecycleStatus: "active",
          employmentStartDateKey: item.startDateKey || null,
          probationEndDateKey: item.probationEndDateKey || null,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      } else {
        transaction.set(employeeRef, {
          lifecycleStatus: "offboarded",
          employmentEndDateKey: item.endDateKey || null,
          isActive: false,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    });

    const uid = await performanceIdentityUid(companyId, item.employeeId);
    if (uid) {
      await db.collection("identities").doc(uid).set({
        isActive: item.type === "onboarding",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      await createUserNotification({
        companyId,
        uid,
        type: "general",
        title: item.type === "onboarding" ?
          "Onboarding completed" :
          "Offboarding completed",
        body: item.type === "onboarding" ?
          "Your onboarding checklist is complete." :
          "Your employee lifecycle workflow has been completed.",
        targetType: "employeeLifecycle",
        targetId: caseId,
      });
    }

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "lifecycle",
      action: item.type === "onboarding" ?
        "completeOnboarding" :
        "completeOffboarding",
      targetType: "employee",
      targetId: item.employeeId,
      summary: `${item.type} workflow completed for ${item.employeeId}.`,
    });
    return {status: "completed"};
  },
);


const ASSET_MANAGEMENT_ROLES = new Set(["companyOwner", "hrAdmin"]);

function assetDate(value, fieldName) {
  if (value === null || value === undefined || value === "") return null;
  const date = asNonEmptyString(value, fieldName);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }
  return date;
}

async function assetEmployee(companyId, employeeId) {
  const ref = db
    .collection("companies")
    .doc(companyId)
    .collection("employees")
    .doc(employeeId);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "Employee was not found.");
  }
  return snapshot.data();
}

exports.getAssetOverview = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const employeeId = asNonEmptyString(caller.employeeId, "employeeId");
    const canManage = ASSET_MANAGEMENT_ROLES.has(caller.role);

    let query = db
      .collection("companies")
      .doc(companyId)
      .collection("assets");

    if (!canManage) {
      query = query.where("assignedEmployeeId", "==", employeeId);
    }

    const snapshot = await query.limit(500).get();
    const assets = snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
    return {canManage, currentEmployeeId: employeeId, assets};
  },
);

exports.createCompanyAsset = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!ASSET_MANAGEMENT_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "HR asset access is required.");
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const assetTag = asNonEmptyString(request.data?.assetTag, "assetTag")
      .trim().slice(0, 80);
    const name = asNonEmptyString(request.data?.name, "name").slice(0, 160);
    const category = asNonEmptyString(request.data?.category, "category")
      .slice(0, 80);
    const serialNumber =
      typeof request.data?.serialNumber === "string" ?
        request.data.serialNumber.trim().slice(0, 160) : "";
    const notes =
      typeof request.data?.notes === "string" ?
        request.data.notes.trim().slice(0, 1500) : "";
    const purchaseDateKey = assetDate(
      request.data?.purchaseDateKey,
      "purchaseDateKey",
    );
    const warrantyExpiryDateKey = assetDate(
      request.data?.warrantyExpiryDateKey,
      "warrantyExpiryDateKey",
    );

    const collection = db
      .collection("companies")
      .doc(companyId)
      .collection("assets");

    const duplicate = await collection
      .where("assetTag", "==", assetTag)
      .limit(1)
      .get();
    if (!duplicate.empty) {
      throw new HttpsError(
        "already-exists",
        "This Asset ID / Tag is already registered.",
      );
    }

    const ref = collection.doc();
    await ref.set({
      companyId,
      assetTag,
      name,
      category,
      serialNumber,
      purchaseDateKey,
      warrantyExpiryDateKey,
      notes,
      status: "available",
      assignedEmployeeId: null,
      assignedEmployeeName: null,
      assignedAt: null,
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "asset",
      action: "createAsset",
      targetType: "asset",
      targetId: ref.id,
      summary: `Created asset ${assetTag} (${name}).`,
    });
    return {assetId: ref.id};
  },
);

exports.assignCompanyAsset = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!ASSET_MANAGEMENT_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "HR asset access is required.");
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const assetId = asNonEmptyString(request.data?.assetId, "assetId");
    const employeeId = asNonEmptyString(request.data?.employeeId, "employeeId");
    const employee = await assetEmployee(companyId, employeeId);
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("assets")
      .doc(assetId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const asset = snapshot.data();
      if (!asset) {
        throw new HttpsError("not-found", "Asset was not found.");
      }
      if (asset.status !== "available") {
        throw new HttpsError(
          "failed-precondition",
          "Only available assets can be assigned.",
        );
      }
      transaction.update(ref, {
        status: "assigned",
        assignedEmployeeId: employeeId,
        assignedEmployeeName:
          employee.displayName || employee.name || employeeId,
        assignedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const uid = await performanceIdentityUid(companyId, employeeId);
    if (uid) {
      await createUserNotification({
        companyId,
        uid,
        type: "general",
        title: "Company asset assigned",
        body: "A company asset has been assigned to you.",
        targetType: "asset",
        targetId: assetId,
      });
    }
    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "asset",
      action: "assignAsset",
      targetType: "asset",
      targetId: assetId,
      summary: `Assigned asset to employee ${employeeId}.`,
    });
    return {status: "assigned"};
  },
);

exports.returnCompanyAsset = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!ASSET_MANAGEMENT_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "HR asset access is required.");
    }
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const assetId = asNonEmptyString(request.data?.assetId, "assetId");
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("assets")
      .doc(assetId);

    const snapshot = await ref.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Asset was not found.");
    }
    if (snapshot.data().status !== "assigned") {
      throw new HttpsError(
        "failed-precondition",
        "This asset is not currently assigned.",
      );
    }

    await ref.update({
      status: "available",
      assignedEmployeeId: null,
      assignedEmployeeName: null,
      returnedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "asset",
      action: "returnAsset",
      targetType: "asset",
      targetId: assetId,
      summary: "Returned company asset.",
    });
    return {status: "available"};
  },
);

exports.updateCompanyAssetStatus = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!ASSET_MANAGEMENT_ROLES.has(caller.role)) {
      throw new HttpsError("permission-denied", "HR asset access is required.");
    }
    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const assetId = asNonEmptyString(request.data?.assetId, "assetId");
    const status = asNonEmptyString(request.data?.status, "status");
    if (!["available", "repair", "retired"].includes(status)) {
      throw new HttpsError("invalid-argument", "Invalid asset status.");
    }

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("assets")
      .doc(assetId);
    const snapshot = await ref.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Asset was not found.");
    }
    if (snapshot.data().status === "assigned") {
      throw new HttpsError(
        "failed-precondition",
        "Return the asset before changing its status.",
      );
    }
    await ref.update({
      status,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await writeAuditLog({
      companyId,
      actor: auditActor(request, caller),
      module: "asset",
      action: "updateAssetStatus",
      targetType: "asset",
      targetId: assetId,
      summary: `Changed asset status to ${status}.`,
    });
    return {status};
  },
);


exports.getAuditLog = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!["companyOwner", "hrAdmin"].includes(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "Only Company Owner or HR can view company audit history.",
      );
    }

    const companyId = asNonEmptyString(caller.companyId, "companyId");
    const allowedAuditModules = new Set([
      "attendance",
      "leave",
      "claims",
      "payroll",
      "employee",
      "asset",
      "lifecycle",
      "performance",
      "documents",
      "workforce",
    ]);
    const requestedModule =
      typeof request.data?.module === "string" ?
        request.data.module.trim() :
        "";
    const module = requestedModule.length > 0 ? requestedModule : null;
    if (module && !allowedAuditModules.has(module)) {
      throw new HttpsError("invalid-argument", "Invalid audit module.");
    }
    const action =
      typeof request.data?.action === "string" &&
      request.data.action.trim().length > 0 ?
        request.data.action.trim().slice(0, 80) :
        null;
    const actorEmployeeId =
      typeof request.data?.actorEmployeeId === "string" &&
      request.data.actorEmployeeId.trim().length > 0 ?
        request.data.actorEmployeeId.trim().slice(0, 120) :
        null;
    const startDateKey =
      typeof request.data?.startDateKey === "string" ?
        request.data.startDateKey.trim() :
        null;
    const endDateKey =
      typeof request.data?.endDateKey === "string" ?
        request.data.endDateKey.trim() :
        null;

    let query = db
      .collection("companies")
      .doc(companyId)
      .collection("auditLogs")
      .orderBy("createdAt", "desc");

    if (module) query = query.where("module", "==", module);
    if (action) query = query.where("action", "==", action);
    if (actorEmployeeId) {
      query = query.where("actorEmployeeId", "==", actorEmployeeId);
    }
    if (startDateKey) {
      query = query.where(
        "createdAt",
        ">=",
        Timestamp.fromDate(new Date(`${startDateKey}T00:00:00.000Z`)),
      );
    }
    if (endDateKey) {
      query = query.where(
        "createdAt",
        "<=",
        Timestamp.fromDate(new Date(`${endDateKey}T23:59:59.999Z`)),
      );
    }

    const snapshot = await query.limit(200).get();
    return {
      entries: snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })),
    };
  },
);
