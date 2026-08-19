import { initializeApp, getApps, getApp } from 'firebase/app';
import { getDatabase } from 'firebase/database';
import { getAuth } from 'firebase/auth';

export const firebaseConfig = {
  apiKey: (import.meta as any).env?.VITE_FIREBASE_API_KEY || "AIzaSyA4d9G11mUPmliqR7kuPpp0zfxlctLq4vU",
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
