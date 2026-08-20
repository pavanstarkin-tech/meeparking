import React, { useEffect, useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Header } from './Header';
import { FirebaseAdminService } from '../../services/firebaseService';
import { UserProfile, SupportTicket, PayoutRequest } from '../../types';

export const AdminLayout: React.FC = () => {
  const location = useLocation();
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [payouts, setPayouts] = useState<PayoutRequest[]>([]);

  useEffect(() => {
    const unsubUsers = FirebaseAdminService.subscribeUsers(setUsers);
    const unsubTickets = FirebaseAdminService.subscribeSupportTickets(setTickets);
    const unsubPayouts = FirebaseAdminService.subscribePayouts(setPayouts);

    return () => {
      unsubUsers();
      unsubTickets();
      unsubPayouts();
    };
  }, []);

  // Close mobile sidebar on route change
  useEffect(() => {
    setIsSidebarOpen(false);
  }, [location.pathname]);

  const pendingApprovalsCount = users.filter((u) => u.role === 'partner' && (!u.isApproved || u.status === 'pending')).length;
  const openTicketsCount = tickets.filter((t) => t.status === 'open' || t.status === 'in_progress').length;
  const pendingPayoutsCount = payouts.filter((p) => p.status === 'pending').length;

  // Derive title from current path
  const getPageInfo = () => {
    switch (location.pathname) {
      case '/':
        return { title: 'Executive Overview', subtitle: 'Real-time analytics and platform performance metrics' };
      case '/map':
        return { title: 'Live Parking Map & Spot Radar', subtitle: 'Real-time interactive slot occupancy, host coordinates & direct comms' };
      case '/bookings':
        return { title: 'Master Bookings Directory', subtitle: 'Live reservation streams, status overrides & refund triggers' };
      case '/users':
        return { title: 'Driver & Seeker Accounts', subtitle: 'Manage registered drivers, wallet balances and personal vehicles' };
      case '/partners':
        return { title: 'Partner Onboarding & KYC Approvals', subtitle: 'Review host applications, verify bank accounts and approve listings' };
      case '/listings':
        return { title: 'Parking Spaces & Approvals', subtitle: 'Verify newly added parking listings, slot quotas and status' };
      case '/pricing':
        return { title: 'Base Pricing & Tariffs', subtitle: 'Configure dynamic platform tariffs and review partner space requests' };
      case '/payouts':
        return { title: 'Payouts & Financial Disbursements', subtitle: 'Process partner bank withdrawals and track commission earnings' };
      case '/support':
        return { title: 'Customer Support & Dispute Center', subtitle: 'Resolve reported parking disputes and issue immediate seeker compensation' };
      case '/settings':
        return { title: 'System & Platform Settings', subtitle: 'Manage Firebase connections, commission percentages and API keys' };
      default:
        return { title: 'Mee Parking Admin', subtitle: 'Enterprise management dashboard' };
    }
  };

  const { title, subtitle } = getPageInfo();

  return (
    <div className="min-h-screen bg-[#F8FAFC] flex">
      {/* Sidebar Navigation */}
      <Sidebar
        isOpen={isSidebarOpen}
        onClose={() => setIsSidebarOpen(false)}
        pendingApprovalsCount={pendingApprovalsCount}
        openTicketsCount={openTicketsCount}
        pendingPayoutsCount={pendingPayoutsCount}
      />

      {/* Main Content Area */}
      <div className="flex-1 lg:ml-64 ml-0 flex flex-col min-w-0 transition-all duration-200">
        <Header
          title={title}
          subtitle={subtitle}
          unreadCount={openTicketsCount + pendingApprovalsCount}
          onToggleSidebar={() => setIsSidebarOpen((prev) => !prev)}
        />
        <main className="p-4 sm:p-6 lg:p-8 flex-1 overflow-x-hidden">
          <Outlet />
        </main>
      </div>
    </div>
  );
};
