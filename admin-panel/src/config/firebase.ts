import { initializeApp, getApps, getApp } from 'firebase/app';
import { getDatabase } from 'firebase/database';
import { getAuth } from 'firebase/auth';
import { decryptSecret } from '../utils/security';

export const firebaseConfig = {
  apiKey: (import.meta as any).env?.VITE_FIREBASE_API_KEY || decryptSecret("0c0c3f3e0338137f2d77006e6228160f5f5c5b471f722e2a0031227b33283f3330310f2e064667"),
  authDomain: (import.meta as any).env?.VITE_FIREBASE_AUTH_DOMAIN || "mee-parking.firebaseapp.com",
  databaseURL: (import.meta as any).env?.VITE_FIREBASE_DATABASE_URL || "https://mee-parking-default-rtdb.firebaseio.com",
  projectId: (import.meta as any).env?.VITE_FIREBASE_PROJECT_ID || "mee-parking",
  storageBucket: (import.meta as any).env?.VITE_FIREBASE_STORAGE_BUCKET || "mee-parking.firebasestorage.app",
  messagingSenderId: (import.meta as any).env?.VITE_FIREBASE_MESSAGING_SENDER_ID || "705882453832",
  appId: (import.meta as any).env?.VITE_FIREBASE_APP_ID || "1:705882453832:web:bac93fa3a5b1485e64e57d"
};

// Initialize Firebase once
export const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
export const db = getDatabase(app);
export const auth = getAuth(app);
