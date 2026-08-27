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
    return {month, status: "finalized"};
  },
);
