import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { ProtectedRoute } from './components/auth/ProtectedRoute';
import { LoginPage } from './pages/LoginPage';
import { AdminLayout } from './components/layout/AdminLayout';
import { DashboardPage } from './pages/DashboardPage';
import { LiveMapPage } from './pages/LiveMapPage';
import { BookingsPage } from './pages/BookingsPage';
import { UsersPage } from './pages/UsersPage';
import { PartnersPage } from './pages/PartnersPage';
import { ListingsPage } from './pages/ListingsPage';
import { OffersPage } from './pages/OffersPage';
import { PayoutsPage } from './pages/PayoutsPage';
import { PricingPage } from './pages/PricingPage';
import { SupportPage } from './pages/SupportPage';
import { SettingsPage } from './pages/SettingsPage';

export function App() {
  return (
    <AuthProvider>
      <Router basename="/meeparking-admin">
        <Routes>
          {/* Public Authentication Route */}
          <Route path="/login" element={<LoginPage />} />

          {/* Protected Super Admin Dashboard Routes */}
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <AdminLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="map" element={<LiveMapPage />} />
            <Route path="bookings" element={<BookingsPage />} />
            <Route path="users" element={<UsersPage />} />
            <Route path="partners" element={<PartnersPage />} />
            <Route path="listings" element={<ListingsPage />} />
            <Route path="offers" element={<OffersPage />} />
            <Route path="pricing" element={<PricingPage />} />
            <Route path="payouts" element={<PayoutsPage />} />
            <Route path="support" element={<SupportPage />} />
            <Route path="settings" element={<SettingsPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </Router>
    </AuthProvider>
  );
}

export default App;
