import { initializeApp } from 'firebase/app';
import { getDatabase, ref, get, remove } from 'firebase/database';

const firebaseConfig = {
  apiKey: "AIzaSyD-dummy",
  authDomain: "mee-parking.firebaseapp.com",
  databaseURL: "https://mee-parking-default-rtdb.firebaseio.com",
  projectId: "mee-parking",
  storageBucket: "mee-parking.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef"
};

const app = initializeApp(firebaseConfig);
const db = getDatabase(app);

async function cleanDummyBookings() {
  console.log("Fetching bookings from Firebase RTDB...");
  const snap = await get(ref(db, 'bookings'));
  if (!snap.exists()) {
    console.log("No bookings found.");
    process.exit(0);
  }

  const data = snap.val();
  let deletedCount = 0;

  for (const [key, value] of Object.entries(data)) {
    const b = value;
    const isDummy =
      (b.totalAmount === 0 || !b.totalAmount) &&
      (!b.spaceTitle || b.spaceTitle === 'Parking Space' || !b.userId || !b.spaceAddress);

    // Also check if id ends with the specified dummy IDs
    const endsWithDummy =
      key.endsWith('827494') ||
      key.endsWith('950188') ||
      key.endsWith('252796') ||
      key.endsWith('295796') ||
      key.endsWith('571183') ||
      b.id?.endsWith('827494') ||
      b.id?.endsWith('950188') ||
      b.id?.endsWith('252796') ||
      b.id?.endsWith('295796') ||
      b.id?.endsWith('571183');

    if (isDummy || endsWithDummy) {
      console.log(`Deleting dummy booking: ${key} (${b.spaceTitle || 'Parking Space'}, ₹${b.totalAmount || 0})`);
      await remove(ref(db, `bookings/${key}`));
      deletedCount++;
    }
  }

  console.log(`Successfully purged ${deletedCount} dummy bookings from Firebase Realtime Database!`);
  process.exit(0);
}

cleanDummyBookings().catch((err) => {
  console.error("Error purging dummy bookings:", err);
  process.exit(1);
});
