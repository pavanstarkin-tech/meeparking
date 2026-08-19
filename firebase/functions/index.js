const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configured SMTP email transporter
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.sendgrid.net",
  port: parseInt(process.env.SMTP_PORT || "587"),
  auth: {
    user: process.env.SMTP_USERNAME || "apikey",
    pass: process.env.SMTP_PASSWORD || "SG.example_key",
  },
});

/**
 * Realtime Database Trigger: On new booking creation
 * 1. Atomically updates capacity counters on /parkingSpaces/{spaceId}
 * 2. Sends FCM Push Notification to driver and partner
 * 3. Sends confirmation email via SMTP
 */
exports.onBookingCreated = functions.database
  .ref("/bookings/{bookingId}")
  .onCreate(async (snapshot, context) => {
    const booking = snapshot.val();
    const { spaceId, userId, partnerId, totalAmount, bookingDate } = booking;

    const db = admin.database();

    // 1. Atomic capacity counter update
    const spaceRef = db.ref(`/parkingSpaces/${spaceId}/capacity`);
    await spaceRef.transaction((capacity) => {
      if (capacity) {
        capacity.currentCars = (capacity.currentCars || 0) + 1;
      }
      return capacity;
    });

    // 2. Fetch User & Partner FCM tokens
    const [userSnap, partnerSnap] = await Promise.all([
      db.ref(`/users/${userId}`).once("value"),
      db.ref(`/partners/${partnerId}`).once("value"),
    ]);

    const user = userSnap.val() || {};
    const partner = partnerSnap.val() || {};

    // 3. Send FCM Push Notification to User
    if (user.fcmToken) {
      await admin.messaging().send({
        token: user.fcmToken,
        notification: {
          title: "Booking Confirmed!",
          body: `Your spot at ${booking.spaceTitle} is reserved for ${bookingDate}.`,
        },
        data: { bookingId: context.params.bookingId },
      });
    }

    // 4. Send FCM Push Notification to Partner
    if (partner.fcmToken) {
      await admin.messaging().send({
        token: partner.fcmToken,
        notification: {
          title: "New Parking Booking Received!",
          body: `Vehicle ${booking.vehicleNumber} booked a slot. Earned ₹${totalAmount}.`,
        },
      });
    }

    // 5. Send Confirmation Email via SMTP
    if (user.email) {
      await transporter.sendMail({
        from: '"Mee Parking" <notifications@meeparking.com>',
        to: user.email,
        subject: `Booking Confirmed - ${booking.id}`,
        html: `
          <h2>Thank you for booking with Mee Parking!</h2>
          <p><strong>Booking ID:</strong> ${booking.id}</p>
          <p><strong>Space:</strong> ${booking.spaceTitle}</p>
          <p><strong>Date & Time:</strong> ${bookingDate} (${booking.timeSlot})</p>
          <p><strong>Total Paid:</strong> ₹${totalAmount}</p>
        `,
      });
    }
  });

/**
 * Realtime Database Trigger: On booking cancellation
 * Decrements active capacity counter
 */
exports.onBookingCancelled = functions.database
  .ref("/bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const before = change.before.val();
    const after = change.after.val();

    if (before.status !== "cancelled" && after.status === "cancelled") {
      const db = admin.database();
      const spaceRef = db.ref(`/parkingSpaces/${after.spaceId}/capacity`);
      await spaceRef.transaction((capacity) => {
        if (capacity && capacity.currentCars > 0) {
          capacity.currentCars -= 1;
        }
        return capacity;
      });
    }
  });
