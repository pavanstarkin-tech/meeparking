# Mee Parking - Admin Dashboard Specification (React + Vite)

This document provides the technical architecture, data model integration, and feature specifications for building the **Mee Parking Admin Web Dashboard** using **React + Vite**.

---

## 🛠️ Recommended Tech Stack

- **Framework**: React 18 + TypeScript (`vite`)
- **Styling**: Tailwind CSS + Shadcn UI / Lucide Icons
- **State & Queries**: `@tanstack/react-query` or React Context API
- **Firebase SDK**: `firebase/app`, `firebase/auth`, `firebase/database`
- **Charts & Analytics**: `recharts` / `chart.js`
- **Routing**: `react-router-dom` v6

---

## 🚀 Quick Setup Instructions

```bash
# 1. Initialize React + TypeScript + Vite app
npm create vite@latest mee-parking-admin -- --template react-ts

# 2. Install dependencies
cd mee-parking-admin
npm install firebase react-router-dom lucide-react recharts @tanstack/react-query
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

---

## 📁 Recommended Directory Structure

```
mee-parking-admin/
  src/
    config/
      firebase.ts          # Firebase Admin SDK initialization
    components/
      Navbar.tsx           # Top nav header
      Sidebar.tsx          # Sidebar routing menu
      StatCard.tsx         # Analytics card component
    pages/
      Dashboard.tsx        # System overview analytics
      Users.tsx            # Drivers & Partners management table
      ParkingSpaces.tsx    # Parking space approval & status overrides
      Bookings.tsx         # Master booking logs & live stream
      Disputes.tsx         # Dispute resolution & manual refund triggers
      EvStations.tsx       # Public & Home EV Charging directory
    types/
      index.ts             # Shared data interfaces
    App.tsx
    main.tsx
```

---

## 🔑 Firebase Realtime Database Data Endpoints

Connect directly to the Mee Parking Realtime Database:

| Route Path | Permission | Description |
| :--- | :--- | :--- |
| `/users` | Read/Write | Full list of all Drivers and Partners |
| `/partners` | Read/Write | Partner verification status & bank details |
| `/parkingSpaces` | Read/Write | All registered spaces (`ownerId`, `status: active\|inactive`, `capacity`) |
| `/bookings` | Read/Write | Master log of all transactions & reservations |
| `/disputes` | Read/Write | User-partner complaint tickets |
| `/evStations` | Read/Write | Public EV charging network locations |

---

## 📊 Core Admin Dashboard Pages & Features

### 1. Overview Dashboard (`pages/Dashboard.tsx`)
- **Key Metrics Summary**:
  - Total Drivers Count
  - Total Verified Partners
  - Total Active Parking Spaces
  - Total Platform Revenue & Commission Earned
- **Realtime Charts**:
  - Daily & Monthly Booking volume (Line Chart).
  - Revenue distribution between Parking Spots vs. EV Charging (Pie Chart).

### 2. Space Approval & Verification (`pages/ParkingSpaces.tsx`)
- Review newly submitted partner parking spaces before they go live on the mobile app.
- **Inspect**:
  - Land Area ($m^2$) & auto-calculated max capacity (`maxCars`, `maxBikes`).
  - High-res images, pricing rules, and location coordinates on an embedded Mapbox web view.
- **Actions**: Approve space (`status: "active"`), Reject space, or Force Inactive.

### 3. User & Partner Management (`pages/Users.tsx`)
- Searchable data table with filters for Role (`user` vs `partner`).
- User profile detail drawer (Vehicles list, Wallet balance, FCM token).
- Action buttons to promote user to Partner or suspend non-compliant accounts.

### 4. Master Booking Logs (`pages/Bookings.tsx`)
- Real-time listener on `/bookings` displaying live bookings.
- Filter by status (`upcoming`, `completed`, `cancelled`).
- Trigger manual wallet refunds or booking cancellations directly from the admin panel.

### 5. Dispute Resolution Center (`pages/Disputes.tsx`)
- Manage reported issues (e.g., driver arrived but space occupied).
- View associated in-app chat transcript (`/chats/{chatId}`).
- Release refund to driver wallet or credit compensation to partner.

---

## 🔐 Firebase Security Rules for Admin Web SDK

Ensure the admin user node or custom claim is authorized in `firebase/database.rules.json`:

```json
{
  "rules": {
    "admin": {
      ".read": "auth != null && auth.token.admin === true",
      ".write": "auth != null && auth.token.admin === true"
    }
  }
}
```
