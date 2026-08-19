import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  MapPin,
  Ticket,
  Users,
  Building2,
  ParkingSquare,
  BadgePercent,
  Headphones,
  Settings,
  ShieldCheck,
  ChevronRight,
} from 'lucide-react';

interface SidebarProps {
  pendingApprovalsCount?: number;
  openTicketsCount?: number;
  pendingPayoutsCount?: number;
}

export const Sidebar: React.FC<SidebarProps> = ({
  pendingApprovalsCount = 0,
  openTicketsCount = 0,
  pendingPayoutsCount = 0,
}) => {
  const navItems = [
    {
      name: 'Overview',
      path: '/',
      icon: LayoutDashboard,
    },
    {
      name: 'Live Map & Spots',
      path: '/map',
      icon: MapPin,
    },
    {
      name: 'Bookings',
      path: '/bookings',
      icon: Ticket,
    },
    {
      name: 'Users & Drivers',
      path: '/users',
      icon: Users,
    },
    {
      name: 'Partners & KYC',
      path: '/partners',
      icon: Building2,
      badge: pendingApprovalsCount > 0 ? pendingApprovalsCount : undefined,
      badgeColor: 'bg-amber-500 text-white',
    },
    {
      name: 'Parking Spaces',
      path: '/listings',
      icon: ParkingSquare,
    },
    {
      name: 'Payouts & Earnings',
      path: '/payouts',
      icon: BadgePercent,
      badge: pendingPayoutsCount > 0 ? pendingPayoutsCount : undefined,
      badgeColor: 'bg-purple-500 text-white',
    },
    {
      name: 'Support & Disputes',
      path: '/support',
      icon: Headphones,
      badge: openTicketsCount > 0 ? openTicketsCount : undefined,
      badgeColor: 'bg-rose-500 text-white',
    },
    {
      name: 'System Settings',
      path: '/settings',
      icon: Settings,
    },
  ];

  return (
    <aside className="w-64 bg-white border-r border-slate-200 flex flex-col h-screen fixed left-0 top-0 z-30 select-none">
      {/* Brand Header */}
      <div className="h-16 flex items-center px-6 border-b border-slate-100 gap-3">
        <div className="w-10 h-10 rounded-xl brand-gradient flex items-center justify-center shadow-md shadow-purple-500/20 text-white">
          <ParkingSquare className="w-6 h-6" />
        </div>
        <div>
          <div className="flex items-center gap-1.5">
            <h1 className="font-extrabold text-base text-slate-900 tracking-tight">Mee Parking</h1>
            <span className="bg-purple-100 text-purple-700 text-[10px] font-bold px-1.5 py-0.2 rounded-md">ADMIN</span>
          </div>
          <p className="text-[11px] text-slate-400 font-medium">Enterprise Management</p>
        </div>
      </div>

      {/* Navigation Links */}
      <div className="flex-1 py-6 px-3 space-y-1 overflow-y-auto">
        <div className="px-3 pb-2 text-[11px] font-bold tracking-wider text-slate-400 uppercase">
          Core Operations
        </div>
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                `flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-semibold transition-all duration-150 ${
                  isActive
                    ? 'bg-purple-50 text-purple-700 shadow-sm border border-purple-100/80 font-bold'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                }`
              }
            >
              <div className="flex items-center gap-3">
                <Icon className="w-4 h-4 text-inherit" />
                <span>{item.name}</span>
              </div>
              {item.badge !== undefined ? (
                <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${item.badgeColor}`}>
                  {item.badge}
                </span>
              ) : (
                <ChevronRight className="w-3.5 h-3.5 opacity-0 group-hover:opacity-100 text-slate-400" />
              )}
            </NavLink>
          );
        })}
      </div>

      {/* Footer / System Status */}
      <div className="p-4 border-t border-slate-100 m-2 bg-slate-50/70 rounded-xl">
        <div className="flex items-center gap-2.5">
          <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
          <div className="text-xs">
            <p className="font-bold text-slate-800">Firebase RTDB Live</p>
            <p className="text-[10px] text-slate-400">Connected to mee-parking</p>
          </div>
        </div>
      </div>
    </aside>
  );
};
