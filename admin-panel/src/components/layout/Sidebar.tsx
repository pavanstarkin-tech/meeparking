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
  Coins,
  Tag,
  X,
} from 'lucide-react';

interface SidebarProps {
  pendingApprovalsCount?: number;
  openTicketsCount?: number;
  pendingPayoutsCount?: number;
  isOpen?: boolean;
  onClose?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  pendingApprovalsCount = 0,
  openTicketsCount = 0,
  pendingPayoutsCount = 0,
  isOpen = false,
  onClose,
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
      name: 'Offers & Promos',
      path: '/offers',
      icon: Tag,
    },
    {
      name: 'Base Pricing & Tariffs',
      path: '/pricing',
      icon: Coins,
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
    <>
      {/* Mobile Backdrop Overlay */}
      {isOpen && (
        <div
          onClick={onClose}
          className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-40 lg:hidden transition-opacity duration-200"
          aria-hidden="true"
        />
      )}

      {/* Sidebar Drawer */}
      <aside
        className={`w-64 bg-white border-r border-slate-200 flex flex-col h-screen fixed left-0 top-0 z-50 select-none transition-transform duration-300 ease-in-out ${
          isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        }`}
      >
        {/* Brand Header + Close Button for Mobile */}
        <div className="h-16 flex items-center justify-between px-6 border-b border-slate-100">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl brand-gradient flex items-center justify-center shadow-md shadow-purple-500/20 text-white shrink-0">
              <ParkingSquare className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-1.5">
                <h1 className="font-extrabold text-base text-slate-900 tracking-tight">Mee Parking</h1>
                <span className="bg-purple-100 text-purple-700 text-[10px] font-bold px-1.5 py-0.2 rounded-md">ADMIN</span>
              </div>
              <p className="text-[11px] text-slate-400 font-medium">Enterprise Portal</p>
            </div>
          </div>

          {/* Close button for mobile drawer */}
          <button
            onClick={onClose}
            className="lg:hidden p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition-colors cursor-pointer"
            aria-label="Close menu"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Navigation Links */}
        <div className="flex-1 py-4 px-3 space-y-1 overflow-y-auto">
          <div className="px-3 pb-2 text-[11px] font-bold tracking-wider text-slate-400 uppercase">
            Core Operations
          </div>
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.path}
                to={item.path}
                onClick={() => {
                  if (onClose) onClose();
                }}
                className={({ isActive }) =>
                  `flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-semibold transition-all duration-150 ${
                    isActive
                      ? 'bg-purple-50 text-purple-700 shadow-sm border border-purple-100/80 font-bold'
                      : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                  }`
                }
              >
                <div className="flex items-center gap-3">
                  <Icon className="w-4 h-4 text-inherit shrink-0" />
                  <span className="truncate">{item.name}</span>
                </div>
                {item.badge !== undefined ? (
                  <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0 ${item.badgeColor}`}>
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
        <div className="p-3.5 border-t border-slate-100 m-2 bg-slate-50/70 rounded-xl">
          <div className="flex items-center gap-2.5">
            <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse shrink-0" />
            <div className="text-xs">
              <p className="font-bold text-slate-800">Firebase RTDB Live</p>
              <p className="text-[10px] text-slate-400 truncate">mee-parking connected</p>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
};
