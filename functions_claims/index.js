"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2/options");

initializeApp();

setGlobalOptions({
  region: "asia-southeast1",
  memory: "256MiB",
  timeoutSeconds: 30,
  maxInstances: 20,
});

const db = getFirestore();
const APPROVER_ROLES = new Set(["companyOwner", "hrAdmin", "manager"]);
const PAYMENT_ROLES = new Set(["companyOwner", "hrAdmin"]);
const CATEGORIES = new Set([
  "Travel",
  "Transport",
  "Meal",
  "Medical",
  "Office",
  "Other",
]);

function asNonEmptyString(value, fieldName, maxLength = 1000) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }

  const normalized = value.trim();
  if (normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} cannot exceed ${maxLength} characters.`,
    );
  }
  return normalized;
}

function optionalString(value, maxLength = 1000) {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLength);
}

function parseDateKey(value, fieldName = "expenseDateKey") {
  const raw = asNonEmptyString(value, fieldName, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must use YYYY-MM-DD.`,
    );
  }

  const parsed = new Date(`${raw}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== raw) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }

  return {raw, date: parsed};
}

async function loadCaller(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to Veyra HRMS first.");
  }

  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  const caller = snapshot.data();

  if (!caller || caller.isActive !== true) {
    throw new HttpsError(
      "permission-denied",
      "Your Veyra HRMS account is inactive.",
    );
  }

  if (
    typeof caller.companyId !== "string" ||
    caller.companyId.trim().length === 0 ||
    typeof caller.employeeId !== "string" ||
    caller.employeeId.trim().length === 0
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Your HRMS identity is incomplete. Contact HR.",
    );
  }

  return {
    ...caller,
    companyId: caller.companyId.trim(),
    employeeId: caller.employeeId.trim(),
  };
}

async function loadEmployee(companyId, employeeId) {
  const snapshot = await db
    .collection("companies")
    .doc(companyId)
    .collection("employees")
    .doc(employeeId)
    .get();

  const employee = snapshot.data();
  if (!employee) {
    throw new HttpsError("not-found", "Employee profile was not found.");
  }
  if (employee.employmentStatus !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "Inactive employees cannot submit expense claims.",
    );
  }

  return employee;
}

async function notifyUser({
  companyId,
  uid,
  type,
  title,
  body,
  claimId,
}) {
  if (!uid) return;

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
      targetType: "claim",
      targetId: claimId,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
}

async function notifyRoles({
  companyId,
  roles,
  title,
  body,
  claimId,
  excludeUid = null,
}) {
  const snapshot = await db
    .collection("users")
    .where("companyId", "==", companyId)
    .get();

  const recipients = snapshot.docs
    .filter((doc) => {
      const data = doc.data();
      return (
        data.isActive === true &&
        roles.has(data.role) &&
        doc.id !== excludeUid
      );
    })
    .map((doc) => doc.id);

  await Promise.all(
    recipients.map((uid) =>
      notifyUser({
        companyId,
        uid,
        type: "claimSubmitted",
        title,
        body,
        claimId,
      }),
    ),
  );
}

async function writeAuditLog({
  companyId,
  request,
  caller,
  action,
  claimId,
  summary,
}) {
  await db
    .collection("companies")
    .doc(companyId)
    .collection("auditLogs")
    .add({
      companyId,
      actorUid: request.auth.uid,
      actorEmployeeId: caller.employeeId || "",
      actorName: caller.displayName || caller.employeeId || "User",
      actorRole: caller.role || "",
      module: "claims",
      action,
      targetType: "claimRequest",
      targetId: claimId,
      summary,
      result: "success",
      metadata: null,
      createdAt: FieldValue.serverTimestamp(),
    });
}

exports.submitExpenseClaimV2 = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = caller.companyId;
    const employeeId = caller.employeeId;

    const title = asNonEmptyString(request.data?.title, "title", 120);
    const amount = Number(request.data?.amount);
    const category = asNonEmptyString(
      request.data?.category,
      "category",
      40,
    );
    const expenseDate = parseDateKey(request.data?.expenseDateKey);
    const description = optionalString(request.data?.description, 2000);
    const receiptPath =
      typeof request.data?.receiptPath === "string" &&
      request.data.receiptPath.trim().length > 0 ?
        request.data.receiptPath.trim() :
        null;

    if (!Number.isFinite(amount) || amount <= 0 || amount > 1000000) {
      throw new HttpsError(
        "invalid-argument",
        "Claim amount must be greater than zero and within the allowed limit.",
      );
    }

    if (!CATEGORIES.has(category)) {
      throw new HttpsError("invalid-argument", "Claim category is invalid.");
    }

    const today = new Date();
    const todayUtc = Date.UTC(
      today.getUTCFullYear(),
      today.getUTCMonth(),
      today.getUTCDate(),
    );
    const expenseUtc = expenseDate.date.getTime();
    const oldestAllowed = todayUtc - 366 * 24 * 60 * 60 * 1000;

    if (expenseUtc > todayUtc) {
      throw new HttpsError(
        "invalid-argument",
        "Expense date cannot be in the future.",
      );
    }
    if (expenseUtc < oldestAllowed) {
      throw new HttpsError(
        "invalid-argument",
        "Expense date is too old to submit.",
      );
    }

    if (
      receiptPath &&
      !receiptPath.startsWith(
        `companies/${companyId}/claims/${employeeId}/`,
      )
    ) {
      throw new HttpsError(
        "permission-denied",
        "The receipt does not belong to this employee claim folder.",
      );
    }

    const employee = await loadEmployee(companyId, employeeId);
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("claimRequests")
      .doc();

    await ref.set({
      companyId,
      employeeId,
      employeeName:
        employee.displayName || caller.displayName || employeeId,
      department: employee.department || caller.department || "",
      title,
      amount: Math.round(amount * 100) / 100,
      category,
      expenseDateKey: expenseDate.raw,
      expenseDate: Timestamp.fromDate(expenseDate.date),
      description,
      receiptPath,
      status: "pending",
      submittedBy: request.auth.uid,
      submittedAt: FieldValue.serverTimestamp(),
      reviewedAt: null,
      reviewerId: null,
      reviewerName: null,
      reviewNote: null,
      paidAt: null,
      paidBy: null,
      paymentReference: null,
      cancelledAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    await notifyRoles({
      companyId,
      roles: APPROVER_ROLES,
      title: "Expense claim submitted",
      body:
        `${employee.displayName || employeeId} submitted ` +
        `RM ${amount.toFixed(2)} for ${title}.`,
      claimId: ref.id,
      excludeUid: request.auth.uid,
    });

    return {
      claimId: ref.id,
      status: "pending",
    };
  },
);

exports.reviewExpenseClaimV2 = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!APPROVER_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to review expense claims.",
      );
    }

    const companyId = caller.companyId;
    const claimId = asNonEmptyString(request.data?.claimId, "claimId", 200);
    const decision = asNonEmptyString(
      request.data?.decision,
      "decision",
      20,
    );
    const note = optionalString(request.data?.note, 1000);

    if (!["approved", "rejected"].includes(decision)) {
      throw new HttpsError(
        "invalid-argument",
        "Decision must be approved or rejected.",
      );
    }

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("claimRequests")
      .doc(claimId);

    let claim;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      claim = snapshot.data();

      if (!claim) {
        throw new HttpsError("not-found", "Expense claim was not found.");
      }
      if (claim.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "This claim has already been reviewed or cancelled.",
        );
      }
      if (
        claim.submittedBy === request.auth.uid ||
        claim.employeeId === caller.employeeId
      ) {
        throw new HttpsError(
          "permission-denied",
          "You cannot review your own expense claim.",
        );
      }

      transaction.update(ref, {
        status: decision,
        reviewerId: request.auth.uid,
        reviewerName:
          caller.displayName || caller.employeeId || "Reviewer",
        reviewNote: note || null,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const employeeSnapshot = await db
      .collection("companies")
      .doc(companyId)
      .collection("employees")
      .doc(claim.employeeId)
      .get();
    const employeeUid = employeeSnapshot.data()?.uid || claim.submittedBy;

    await notifyUser({
      companyId,
      uid: employeeUid,
      type:
        decision === "approved" ?
          "claimApproved" :
          "claimRejected",
      title:
        decision === "approved" ?
          "Expense claim approved" :
          "Expense claim rejected",
      body:
        `${claim.title || "Expense claim"} was ${decision}.`,
      claimId,
    });

    await writeAuditLog({
      companyId,
      request,
      caller,
      action:
        decision === "approved" ?
          "approveExpenseClaim" :
          "rejectExpenseClaim",
      claimId,
      summary: `${decision} expense claim ${claimId}.`,
    });

    return {claimId, status: decision};
  },
);

exports.cancelExpenseClaimV2 = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    const companyId = caller.companyId;
    const claimId = asNonEmptyString(request.data?.claimId, "claimId", 200);
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("claimRequests")
      .doc(claimId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const claim = snapshot.data();

      if (
        !claim ||
        claim.employeeId !== caller.employeeId ||
        claim.submittedBy !== request.auth.uid
      ) {
        throw new HttpsError("not-found", "Expense claim was not found.");
      }
      if (claim.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "Only pending expense claims can be cancelled.",
        );
      }

      transaction.update(ref, {
        status: "cancelled",
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {claimId, status: "cancelled"};
  },
);

exports.markExpenseClaimPaidV2 = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const caller = await loadCaller(request);
    if (!PAYMENT_ROLES.has(caller.role)) {
      throw new HttpsError(
        "permission-denied",
        "Only Company Owner or HR Admin can mark claims as paid.",
      );
    }

    const companyId = caller.companyId;
    const claimId = asNonEmptyString(request.data?.claimId, "claimId", 200);
    const paymentReference = optionalString(
      request.data?.paymentReference,
      120,
    );

    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("claimRequests")
      .doc(claimId);

    let claim;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      claim = snapshot.data();

      if (!claim) {
        throw new HttpsError("not-found", "Expense claim was not found.");
      }
      if (claim.status !== "approved") {
        throw new HttpsError(
          "failed-precondition",
          "Only approved claims can be marked as paid.",
        );
      }

      transaction.update(ref, {
        status: "paid",
        paidAt: FieldValue.serverTimestamp(),
        paidBy: request.auth.uid,
        paymentReference: paymentReference || null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const employeeSnapshot = await db
      .collection("companies")
      .doc(companyId)
      .collection("employees")
      .doc(claim.employeeId)
      .get();
    const employeeUid = employeeSnapshot.data()?.uid || claim.submittedBy;

    await notifyUser({
      companyId,
      uid: employeeUid,
      type: "claimPaid",
      title: "Expense claim paid",
      body:
        `${claim.title || "Expense claim"} has been marked as paid.`,
      claimId,
    });

    await writeAuditLog({
      companyId,
      request,
      caller,
      action: "markExpenseClaimPaid",
      claimId,
      summary: `Marked expense claim ${claimId} as paid.`,
    });

    return {claimId, status: "paid"};
  },
);
