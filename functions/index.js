/* eslint-disable linebreak-style */
/* eslint-disable padded-blocks */
/* eslint linebreak-style: ["error", "windows"] */
/* eslint-disable indent, max-len, space-in-parens, no-multi-spaces, key-spacing, object-curly-spacing, comma-dangle */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const nodemailer = require("nodemailer");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

admin.initializeApp();

const FIREBASE_API_KEY = "AIzaSyD1-qmYt3fwlA-TlHmxHOhd_DL3lmj5TF0";

exports.sendEmail = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
        const { smtp_host, smtp_user, smtp_pass, from, from_name, to, subject, message } = req.body;

        if (!smtp_user || !smtp_pass || !to || !subject || !message) {
            return res.status(400).json({ success: false, error: "Missing required fields" });
        }

        const transporter = nodemailer.createTransport({
            host: smtp_host || "smtp.gmail.com",
            port: 465,
            secure: true,
            auth: { user: smtp_user, pass: smtp_pass },
        });

        await transporter.sendMail({
            from: `"${from_name || "Leadcapture"}" <${from || smtp_user}>`,
            to: to,
            replyTo: from || smtp_user,
            subject: subject,
            html: message,
        });

        return res.status(200).json({ success: true, message: "Email sent successfully" });
    } catch (error) {
        console.error("sendEmail error:", error);
        return res.status(500).json({ success: false, error: error.message });
    }
});

exports.verifyAuth = functions.https.onRequest(async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ success: false, error: "Missing email or password" });
        }

        // Call Firebase Authentication REST API to verify credentials
        const response = await axios.post(
            `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
            {
                email,
                password,
                returnSecureToken: true
            }
        );

        return res.status(200).json({ success: true, data: response.data });

    } catch (error) {
        let errorMessage = "Authentication failed";

        if (error.response && error.response.data && error.response.data.error && error.response.data.error.message) {
            errorMessage = error.response.data.error.message;
        }

        return res.status(400).json({
            success: false,
            error: errorMessage
        });
    }
});

exports.updateUserPassword = functions.https.onRequest(async (req, res) => {
    try {
        const { email, newPassword } = req.body;

        if (!email || !newPassword) {
            return res.status(400).json({ success: false, error: "Missing email or password" });
        }

        const user = await admin.auth().getUserByEmail(email);
        await admin.auth().updateUser(user.uid, { password: newPassword });

        res.json({ success: true, message: `Password updated for ${email}` });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
});

exports.deleteUserByEmail = functions.https.onRequest(async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ success: false, error: "Missing email" });
        }

        const user = await admin.auth().getUserByEmail(email);
        await admin.auth().deleteUser(user.uid);

        res.json({ success: true, message: `User with email ${email} deleted` });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
});

exports.removeoldNotifications = onSchedule(
    {
        schedule: "every 24 hours",
        timeZone: "Asia/Kolkata",
    },
    async (event) => {
        const db = getFirestore();
        const now = Timestamp.now();
        const cutoff = new Date(now.toDate().getTime() - 7 * 24 * 60 * 60 * 1000);

        console.log(`Cleaning notifications older than: ${cutoff.toISOString()}`);

        try {
            const usersSnapshot = await db.collection("users").get();
            let totalDeleted = 0;

            for (const userDoc of usersSnapshot.docs) {
                const notificationsRef = userDoc.ref.collection("notifications");
                const oldRecordsSnapshot = await notificationsRef
                    .where("timestamp", "<", cutoff)
                    .get();

                if (!oldRecordsSnapshot.empty) {
                    const batch = db.batch();
                    oldRecordsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
                    await batch.commit();
                    totalDeleted += oldRecordsSnapshot.size;
                }
            }

            console.log(`Total old notifications deleted: ${totalDeleted}`);
            return null;
        } catch (error) {
            console.error("Error cleaning notifications:", error);
            return null;
        }
    }
);

// Splits an array into chunks of at most `size` (FCM multicast max is 500).
function chunk(array, size) {
    const out = [];
    for (let i = 0; i < array.length; i += size) {
        out.push(array.slice(i, i + size));
    }
    return out;
}

exports.reminderScheduler = onSchedule("every 1 minutes", async () => {
    const now = Timestamp.now();
    const db = getFirestore();

    const snapshot = await db
        .collection("reminders")
        .where("isSent", "==", false)
        .where("scheduledAt", "<=", now)
        .get();

    for (const doc of snapshot.docs) {
        // Claim the reminder inside a transaction first, so an overlapping
        // scheduler run (or a retried invocation) can never send it twice.
        const claimed = await db.runTransaction(async (tx) => {
            const fresh = await tx.get(doc.ref);
            if (!fresh.exists || fresh.data().isSent === true) return false;
            tx.update(doc.ref, { isSent: true, sentAt: FieldValue.serverTimestamp() });
            return true;
        });
        if (!claimed) continue;

        const reminder = doc.data();
        const notif = reminder.notification || {};

        try {
            // Send FCM (batched — sendEachForMulticast caps at 500 tokens/call)
            if (notif.toFcms && notif.toFcms.length > 0) {
                for (const batch of chunk(notif.toFcms, 500)) {
                    await getMessaging().sendEachForMulticast({
                        tokens: batch,
                        data: {
                            ...(notif.payload || {}),
                            title: String(notif.title || ""),
                            body: String(notif.body || ""),
                            type: String(notif.type || ""),
                        },
                        android: { priority: "high" },
                        apns: {
                            headers: { "apns-priority": "10" },
                            payload: { aps: { "content-available": 1 } },
                        },
                    });
                }
            }

            // Save notification to sub-collection
            if (notif.collectionId) {
                await db
                    .collection("users")
                    .doc(notif.collectionId)
                    .collection("notifications")
                    .add({
                        title: notif.title,
                        body: notif.body,
                        toFcms: notif.toFcms || [],
                        toUids: notif.toUids || [],
                        senderId: notif.senderId || null,
                        type: notif.type || null,
                        payload: notif.payload || {},
                        createdAt: Date.now(),
                    });
            }
        } catch (error) {
            console.error(`reminderScheduler: failed to send reminder ${doc.id}:`, error);
        }
    }
});

// ─────────────────────────────────────────────────────────────────────────
// EVENT "STARTED" BROADCAST — notify ALL company users at the exact
// event start time, even if the app is closed/killed.
//
// Flow:
//   Flutter app writes users/{cid}/events/{eventId}
//     -> onEventWritten (this trigger) upserts
//        eventStartNotifications/{cid}_{eventId} with status "pending"
//        and scheduledAt = event start time.
//     -> sendEventStartNotifications (runs every 1 minute) claims every
//        "pending" doc whose scheduledAt has passed, fetches every admin's
//        FCM tokens for that company, and sends the FCM in batches.
//
// This never relies on the client's app being open — the whole pipeline
// runs in Cloud Functions / Firestore.
// ─────────────────────────────────────────────────────────────────────────

exports.onEventWritten = onDocumentWritten(
    "users/{cid}/events/{eventId}",
    async (event) => {
        const { cid, eventId } = event.params;
        const db = getFirestore();
        const notifRef = db.collection("eventStartNotifications").doc(`${cid}_${eventId}`);

        const afterSnap = event.data && event.data.after;
        const beforeSnap = event.data && event.data.before;
        const after = afterSnap && afterSnap.exists ? afterSnap.data() : null;

        // Event was deleted -> cancel the scheduled broadcast (requirement:
        // deleted/cancelled events must not send a notification).
        if (!after) {
            await notifRef.set(
                {
                    status: "cancelled",
                    updatedAt: FieldValue.serverTimestamp(),
                },
                { merge: true },
            );
            return;
        }

        if (!after.eventDateTime) return; // malformed doc, nothing to schedule

        const newScheduledAt = Timestamp.fromMillis(after.eventDateTime);
        const existing = await notifRef.get();

        if (existing.exists) {
            const data = existing.data();
            const storedMillis = data.scheduledAt ? data.scheduledAt.toMillis() : null;
            const timeChanged = storedMillis !== newScheduledAt.toMillis();

            // Already sent and the time hasn't changed on this edit -> leave
            // it alone (prevents re-sending on unrelated field edits, and
            // prevents duplicate sends from repeated trigger invocations).
            if (data.status === "sent" && !timeChanged) return;

            // Already pending and nothing relevant changed -> just refresh
            // the denormalized display fields, keep status as-is.
            if (data.status === "pending" && !timeChanged) {
                await notifRef.set(
                    {
                        eventName: after.eventName || "",
                        eventDescription: after.eventDescription || "",
                        updatedAt: FieldValue.serverTimestamp(),
                    },
                    { merge: true },
                );
                return;
            }
        }

        // New event, edited/rescheduled time, or a previously
        // sent/cancelled event that is active again -> (re)schedule.
        await notifRef.set(
            {
                cid,
                eventId,
                eventName: after.eventName || "",
                eventDescription: after.eventDescription || "",
                scheduledAt: newScheduledAt,
                status: "pending",
                createdUserId:
                    (after.createdBy && after.createdBy.uid) || null,
                createdAt:
                    (existing.exists && existing.data().createdAt) ||
                    FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
                sentAt: FieldValue.delete(),
                lastError: FieldValue.delete(),
            },
            { merge: true },
        );
    },
);

exports.sendEventStartNotifications = onSchedule(
    { schedule: "every 1 minutes", timeZone: "Asia/Kolkata" },
    async () => {
        const db = getFirestore();
        const now = Timestamp.now();

        const snapshot = await db
            .collection("eventStartNotifications")
            .where("status", "==", "pending")
            .where("scheduledAt", "<=", now)
            .limit(100)
            .get();

        for (const doc of snapshot.docs) {
            // Claim it first (transactional compare-and-set) so overlapping
            // or retried invocations can never send the same event twice.
            const claimed = await db.runTransaction(async (tx) => {
                const fresh = await tx.get(doc.ref);
                if (!fresh.exists || fresh.data().status !== "pending") return null;
                tx.update(doc.ref, { status: "sending" });
                return fresh.data();
            });
            if (!claimed) continue;

            try {
                const wasSent = await sendEventStartedBroadcast(claimed);
                if (wasSent) {
                    await doc.ref.update({
                        status: "sent",
                        sentAt: FieldValue.serverTimestamp(),
                    });
                } else {
                    // No valid FCM tokens found - mark as failed with appropriate message
                    await doc.ref.update({
                        status: "failed",
                        lastError: "No valid FCM tokens found for company admins",
                        updatedAt: FieldValue.serverTimestamp(),
                    });
                }
            } catch (error) {
                console.error(`sendEventStartNotifications: failed for ${doc.id}:`, error);
                await doc.ref.update({
                    status: "failed",
                    lastError: String((error && error.message) || error),
                    updatedAt: FieldValue.serverTimestamp(),
                });
            }
        }
    },
);

/**
 * Sends the "Event Started" push to every admin/user in the event's
 * company, cleans up invalid FCM tokens it discovers along the way, and
 * writes a notification record every user can see in-app.
 * Returns true if at least one FCM message was sent successfully, false otherwise.
 */
async function sendEventStartedBroadcast(eventNotif) {
    const db = getFirestore();
    const cid = eventNotif.cid;

    const adminsSnap = await db
        .collection("users")
        .doc(cid)
        .collection("admins")
        .get();

    // token -> { adminDocRef, devices, tokenIndex } so we can prune bad
    // tokens from the exact device entry that owns them.
    const tokenOwners = new Map();
    const allUids = [];

    adminsSnap.docs.forEach((adminDoc) => {
        allUids.push(adminDoc.id);
        const devices = adminDoc.data().devices || [];
        devices.forEach((device, idx) => {
            if (device && device.fcmId) {
                tokenOwners.set(device.fcmId, { ref: adminDoc.ref, devices, idx });
            }
        });
    });

    const tokens = Array.from(tokenOwners.keys());
    const invalidTokens = [];
    // let successfulSends = 0;

    if (tokens.length > 0) {
        const eventTitle = "Event Started";
        const eventBody = `${eventNotif.eventName || "An event"} has started now.`;
        const payload = {
            data: {
                type: "eventStarted",
                title: eventTitle,
                body: eventBody,
                eventId: String(eventNotif.eventId || ""),
                cid: String(cid || ""),
            },
            android: { priority: "high" },
            apns: {
                headers: { "apns-priority": "10" },
                payload: { aps: { "content-available": 1 } },
            },
        };

        for (const batch of chunk(tokens, 500)) {
            const response = await getMessaging().sendEachForMulticast({
                tokens: batch,
                ...payload,
            });
            response.responses.forEach((res, i) => {
                if (!res.success) {
                    
                    const code = res.error && res.error.code;
                    if (
                        code === "messaging/invalid-registration-token" ||
                        code === "messaging/registration-token-not-registered"
                    ) {
                        invalidTokens.push(batch[i]);
                    }
                }
            });
        }
    }

    // Remove dead tokens from the owning admin's `devices` array so future
    // sends don't keep retrying them (requirement: remove invalid/expired
    // tokens when detected).
    const byRef = new Map();
    invalidTokens.forEach((t) => {
        const owner = tokenOwners.get(t);
        if (!owner) return;
        const key = owner.ref.path;
        if (!byRef.has(key)) byRef.set(key, { ref: owner.ref, devices: [...owner.devices] });
        const entry = byRef.get(key);
        entry.devices = entry.devices.map((d) =>
            d.fcmId === t ? { ...d, fcmId: null } : d,
        );
    });
    await Promise.all(
        Array.from(byRef.values()).map(({ ref, devices }) => ref.update({ devices })),
    );

    // One in-app notification record every user in the company can see.
    if (allUids.length > 0) {
        await db
            .collection("users")
            .doc(cid)
            .collection("notifications")
            .add({
                title: "Event Started",
                body: `${eventNotif.eventName || "An event"} has started now.`,
                toUids: allUids,
                toFcms: tokens,
                type: "eventStarted",
                payload: { eventId: String(eventNotif.eventId || "") },
                createdAt: Date.now(),
            });
    }

    
}
