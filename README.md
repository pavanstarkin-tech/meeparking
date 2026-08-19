# 🅿️ Mee Parking – Smart Parking Marketplace

> **"Park Smart. Earn Smart."**
> A complete, production-ready Flutter application for seamless parking space discovery, dynamic slot booking, EV charging station navigation, in-app face-to-face video calling, realtime chat, and partner space monetization.

<img src="designui.png" alt="Mee Parking Design UI Reference" width="100%" />

---

## 🌟 Key Features & Accomplishments (Summary of Work Done)

### 🎨 1. Pixel-Perfect UI Screens (15 Screens + Admin Spec)
- **01 Splash Screen**: Animated dark purple gradient city skyline, glowing Mee Parking 'M' logo, purple sedan car illustration with floating 'P' badge, progress loader.
- **02 Onboarding**: "Smart Parking Made Simple" page view slider, custom illustrations, indicator pills, Next & Skip buttons.
- **Authentication Screens**:
  - **Login Screen (`lib/features/auth/login_screen.dart`)**: Email & Password sign-in, Google Authentication button, Forgot Password recovery.
  - **Sign Up Screen (`lib/features/auth/signup_screen.dart`)**: Full Name, Email, Password, and Vehicle Registration registration form.
- **03 Home Screen**: User header, notification badge, location search, "Find Parking" & "EV Charging" feature cards, 4 quick pills (Offers, Favourites, Recent, Partner), popular locations carousel, user bottom navigation bar.
- **04 Search Parking Screen**: Interactive map with purple price markers (`₹60`, `₹80`, `₹120`), horizontal filter chips (Nearby, EV Charging, Covered, CCTV), expandable bottom list card of spaces.
- **05 Parking Details Screen**: Image carousel, rating (`4.6 (128)`), distance, amenity badges, pricing cards (hourly, daily, weekly, monthly), owner contact card (Chat & Face-to-Face Call), "Select Slot" CTA.
- **06 Booking Screen**: Date selector pills (Mon 20 May - Thu 23 May), time slot grid, vehicle selector card (`DL 01 AB 1234`), price breakdown, "Continue to Payment" button.
- **07 Booking Confirmed Screen**: Green checkmark success badge with glow, purple car graphic, summary card with ID `MEE12345678`, "View Booking" & "Go Home" options.
- **08 Turn-by-Turn Navigation Screen**: Dark HUD map view, top direction banner ("120 m - Turn right"), route polyline, camera/mute controls, ETA HUD (`8 min`, `2.4 km`), Exit button.
- **09 My Bookings Screen**: Segmented tabs (Upcoming, Completed, Cancelled), booking cards with status pills & direct "Navigate" button.
- **10 Wallet Screen**: Wallet Balance Card (`₹1,250.00`) with 3D wallet vector & gold coins, "+ Add Money" modal popup with Razorpay payment flow, credit/debit transaction log.
- **11 Become Partner Screen**: Hero banner illustration, garage & car graphic, benefits checklist with green checkmarks, "Get Started" onboarding form.
- **12 Partner Dashboard Screen**: "Welcome back, Arun Kumar", 4 stats cards (Total Listings: 12, Today's Bookings: 15, Monthly Earnings: ₹12,450, Total Views: 1,245), recent bookings list, partner bottom nav bar.
- **13 My Listings Screen**: Partner's space cards, available slots count ("18 Slots Available"), Active/Inactive status toggle switch, "+ Add Listing" button.
- **14 Earnings Screen**: Total Earnings card (`₹12,450`), Daily/Weekly/Monthly filter toggle, `fl_chart` line graph, earnings breakdown (Parking Bookings vs EV Charging).
- **15 Profile Screen**: User avatar, name ("Rohan Sharma"), phone ("+91 98765 43210"), Edit Profile CTA, Role Switcher toggle (User Mode vs Partner Mode), menu list & Logout.

---

### 📹 2. Face-to-Face Connection & Realtime Chat
- **Face-to-Face Video/Audio Call HUD (`lib/features/chat/call_screen.dart`)**:
  - Fullscreen caller video stream background with dark overlay gradient.
  - Live call timer (`02:45`), caller metadata header.
  - Floating self-camera Picture-in-Picture (PIP) window.
  - Glassmorphic control bar: Mute Mic, Toggle Camera, Switch Front/Back Camera, and End Call red button.
- **In-App Realtime Messaging (`lib/features/chat/chat_screen.dart`)**:
  - Live driver-partner chat bubbles, timestamps, and top bar voice/video call triggers.

---

### ⚙️ 3. Environment & Backend Deliverables
- **Environment File ([.env](file:///.env))**:
  - Configuration keys for Mapbox, Firebase, Razorpay, Cloudinary, Agora, and SMTP Email.
- **Firebase Cloud Functions ([firebase/functions/index.js](file:///firebase/functions/index.js))**:
  - Realtime Database trigger for atomic capacity counter updates (`currentCars`, `currentBikes`).
  - Automated FCM push notifications and SMTP booking confirmation emails.
- **Firebase Rules ([firebase/database.rules.json](file:///firebase/database.rules.json))**:
  - Security rules & indexing on `ownerId`, `status`, `lat`, `lng`, `city`.
- **React + Vite Admin Panel Specification ([admin.md](file:///admin.md))**:
  - Full architecture blueprint for creating a separate web admin dashboard in React + Vite.

---

## 🏗️ Technical Architecture & Directory Structure

```
meeparking/
├── .env                              # API Environment keys
├── admin.md                          # React + Vite Web Admin specification blueprint
├── designui.png                      # Pixel-perfect UI Reference image
├── firebase/
│   ├── database.rules.json           # Firebase Realtime Database Security Rules
│   └── functions/index.js            # Node.js Cloud Functions for counters & emails
├── lib/
│   ├── main.dart                     # App entry point & Theme configuration
│   ├── core/
│   │   ├── config/env_config.dart    # Environment loader (.env reader)
│   │   ├── constants/app_colors.dart # Theme palette & custom gradients
│   │   └── services/                 # Parking, Booking, Wallet, & Chat services
│   ├── shared/
│   │   ├── models/                   # ParkingSpace, Booking, UserProfile, WalletTransaction, ChatMessage
│   │   ├── providers/app_providers.dart # Riverpod state providers
│   │   └── widgets/mee_parking_illustrations.dart # Vector drawings (Car, Wallet, Coins)
│   └── features/
│       ├── splash/                   # Screen 01
│       ├── onboarding/               # Screen 02
│       ├── home/                     # Screen 03
│       ├── search/                   # Screen 04
│       ├── parking/                  # Screen 05
│       ├── booking/                  # Screens 06 & 07
│       ├── navigation/               # Screen 08
│       ├── bookings/                 # Screen 09
│       ├── wallet/                   # Screen 10
│       ├── partner/                  # Screens 11, 12, 13, 14
│       ├── profile/                  # Screen 15
│       └── chat/                     # Realtime Chat & Face-to-Face Video Call screens
```

---

## ⚡ How to Run & Verify

### 1. Run Flutter Analyze
Ensure zero errors or static analysis warnings:
```bash
flutter analyze
```

### 2. Launch Mobile Application
Run on connected Android/iOS emulator or physical device:
```bash
flutter run
```

---

## ✅ Quality & Verification Status
- **Flutter Analyze Status**: `No issues found!` (0 errors).
- **All 15 UI Screens**: Pixel-perfect match with `designui.png`.
- **End-to-End Interconnection**: Fully connected navigation, role switching, wallet updates, booking creation, turn-by-turn navigation, and face-to-face video calling.
