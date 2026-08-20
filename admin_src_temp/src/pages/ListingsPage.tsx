import React, { useEffect, useState } from 'react';
import {
  ParkingSquare,
  Search,
  CheckCircle2,
  XCircle,
  MapPin,
  Eye,
  Zap,
  Power,
  DollarSign,
  Layers,
  AlertTriangle,
} from 'lucide-react';
import { StatusBadge } from '../components/common/StatusBadge';
import { Modal } from '../components/common/Modal';
import { FirebaseAdminService } from '../services/firebaseService';
import { ParkingSpace } from '../types';

export const ListingsPage: React.FC = () => {
  const [spaces, setSpaces] = useState<ParkingSpace[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'pending' | 'active' | 'all' | 'inactive'>('all');
  const [selectedSpace, setSelectedSpace] = useState<ParkingSpace | null>(null);
  const [rejectModalSpace, setRejectModalSpace] = useState<ParkingSpace | null>(null);
  const [rejectionReason, setRejectionReason] = useState('Inadequate location verification or unclear imagery');
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    const unsub = FirebaseAdminService.subscribeParkingSpaces(setSpaces);
    return () => unsub();
  }, []);

  const filteredSpaces = spaces.filter((s) => {
    const query = searchQuery.toLowerCase().trim();
    const matchesSearch =
      s.title.toLowerCase().includes(query) ||
      s.address.toLowerCase().includes(query) ||
      s.id.toLowerCase().includes(query) ||
      s.ownerId.toLowerCase().includes(query);

    if (statusFilter === 'pending') {
      return matchesSearch && (s.status === 'pending' || !s.status);
    }
    if (statusFilter === 'active') {
      return matchesSearch && s.isActive && s.status === 'approved';
    }
    if (statusFilter === 'inactive') {
      return matchesSearch && !s.isActive;
    }
    return matchesSearch;
  });

  const handleApproveSpace = async (spaceId: string) => {
    setIsProcessing(true);
    try {
      await FirebaseAdminService.approveParkingSpace(spaceId);
    } catch (e) {
      console.error('Space approval error:', e);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleExecuteReject = async () => {
    if (!rejectModalSpace) return;
    setIsProcessing(true);
    try {
      await FirebaseAdminService.rejectParkingSpace(rejectModalSpace.id, rejectionReason);
      setRejectModalSpace(null);
    } catch (e) {
      console.error('Space rejection error:', e);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleToggleActive = async (space: ParkingSpace) => {
    await FirebaseAdminService.toggleSpaceActive(space.id, !space.isActive);
  };

  const pendingCount = spaces.filter((s) => s.status === 'pending' || !s.status).length;

  return (
    <div className="space-y-6">
      {/* Policy Banner */}
      <div className="bg-gradient-to-r from-purple-900 to-indigo-900 rounded-2xl p-5 text-white shadow-md flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <span className="bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-full">
              ⚡ Live Governance Workflow
            </span>
            <h3 className="font-extrabold text-base text-white">Listing Review & Approval Gatekeeper</h3>
          </div>
          <p className="text-xs text-purple-200/90 max-w-3xl leading-relaxed">
            Partner accounts are automatically approved upon registration. However, all new parking spaces submitted by partners are placed under <strong>Review</strong> and remain hidden from public seekers until approved by an Admin below.
          </p>
        </div>

        {pendingCount > 0 && (
          <div className="bg-amber-500/20 border border-amber-400/40 rounded-xl px-4 py-2 flex items-center gap-2 shrink-0">
            <span className="w-2 h-2 rounded-full bg-amber-400 animate-ping" />
            <span className="text-xs font-bold text-amber-200">
              {pendingCount} Listing{pendingCount > 1 ? 's' : ''} Pending Admin Review
            </span>
          </div>
        )}
      </div>

      {/* Search & Tabs Bar */}
      <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by Space Name, Address, Owner ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-10 pr-4 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
          />
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600">
            {[
              { id: 'all', label: 'All Listings' },
              { id: 'pending', label: `Pending Review (${pendingCount})` },
              { id: 'active', label: 'Approved & Live' },
              { id: 'inactive', label: 'Inactive' },
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setStatusFilter(tab.id as any)}
                className={`px-3 py-1 rounded-lg capitalize transition-all ${
                  statusFilter === tab.id
                    ? 'bg-white text-purple-700 font-bold shadow-sm'
                    : 'hover:text-slate-900'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Listings Grid */}
      {filteredSpaces.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-100 p-16 text-center text-slate-400 shadow-sm">
          <ParkingSquare className="w-10 h-10 mx-auto text-slate-300 mb-3" />
          <p className="font-bold text-slate-700">No parking spaces found</p>
          <p className="text-xs text-slate-400 mt-1">Try another search or filter parameter.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredSpaces.map((space) => {
            const isPending = space.status === 'pending' || !space.status;
            const thumbnail =
              space.images && space.images.length > 0
                ? space.images[0]
                : 'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?auto=format&fit=crop&w=600&q=80';

            return (
              <div
                key={space.id}
                className="bg-white rounded-2xl border border-slate-100 overflow-hidden shadow-sm hover:shadow-md transition-all duration-200 flex flex-col justify-between"
              >
                <div>
                  {/* Space Image & Badges Overlay */}
                  <div className="relative h-44 w-full bg-slate-100 overflow-hidden">
                    <img src={thumbnail} alt={space.title} className="w-full h-full object-cover" />
                    <div className="absolute top-3 left-3 flex gap-1.5">
                      <span
                        className={`text-[10px] font-bold px-2.5 py-1 rounded-full backdrop-blur-md shadow-sm ${
                          isPending
                            ? 'bg-amber-500/90 text-white'
                            : space.isActive
                            ? 'bg-emerald-600/90 text-white'
                            : 'bg-slate-700/90 text-white'
                        }`}
                      >
                        {isPending ? 'Pending Approval' : space.isActive ? 'Live & Active' : 'Inactive'}
                      </span>
                      {space.isEvCharging && (
                        <span className="bg-emerald-500 text-white text-[10px] font-bold px-2 py-1 rounded-full flex items-center gap-1 shadow-sm">
                          <Zap className="w-3 h-3 fill-white" /> EV Fast Charging
                        </span>
                      )}
                    </div>
                    <div className="absolute bottom-3 right-3 bg-slate-900/80 backdrop-blur-sm text-white px-2.5 py-1 rounded-lg text-xs font-extrabold">
                      ₹{space.pricing.hourly}/hr
                    </div>
                  </div>

                  {/* Body Info */}
                  <div className="p-5 space-y-3">
                    <div>
                      <h4 className="font-bold text-slate-900 text-sm leading-tight line-clamp-1">
                        {space.title}
                      </h4>
                      <p className="text-xs text-slate-500 mt-1 flex items-center gap-1 line-clamp-1">
                        <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                        {space.address}
                      </p>
                    </div>

                    {/* Capacity & Pricing Matrix */}
                    <div className="grid grid-cols-2 gap-2 bg-slate-50 p-2.5 rounded-xl border border-slate-100 text-xs">
                      <div>
                        <span className="text-[10px] text-slate-400 font-bold block">CAPACITY</span>
                        <span className="font-bold text-slate-800">
                          {space.availableSlots} / {space.totalSlots} Slots
                        </span>
                      </div>
                      <div>
                        <span className="text-[10px] text-slate-400 font-bold block">DAILY PASS</span>
                        <span className="font-bold text-slate-800">₹{space.pricing.daily}</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Footer Controls */}
                <div className="p-5 pt-0 flex items-center gap-2">
                  <button
                    onClick={() => setSelectedSpace(space)}
                    className="flex-1 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors"
                  >
                    <Eye className="w-3.5 h-3.5" /> Inspect
                  </button>

                  {isPending ? (
                    <>
                      <button
                        onClick={() => handleApproveSpace(space.id)}
                        disabled={isProcessing}
                        className="flex-1 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 shadow-sm transition-colors"
                      >
                        <CheckCircle2 className="w-3.5 h-3.5" /> Approve
                      </button>
                      <button
                        onClick={() => setRejectModalSpace(space)}
                        className="py-2 px-3 bg-rose-50 hover:bg-rose-100 text-rose-700 font-bold rounded-xl text-xs"
                        title="Reject Space"
                      >
                        <XCircle className="w-4 h-4" />
                      </button>
                    </>
                  ) : (
                    <button
                      onClick={() => handleToggleActive(space)}
                      className={`flex-1 py-2 font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors ${
                        space.isActive
                          ? 'bg-rose-50 text-rose-700 hover:bg-rose-100'
                          : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                      }`}
                    >
                      <Power className="w-3.5 h-3.5" /> {space.isActive ? 'Deactivate' : 'Activate'}
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Space Details Modal */}
      {selectedSpace && (
        <Modal
          isOpen={Boolean(selectedSpace)}
          onClose={() => setSelectedSpace(null)}
          title={`Parking Space: ${selectedSpace.title}`}
          subtitle={`Space ID: ${selectedSpace.id}`}
        >
          <div className="space-y-6 text-xs text-slate-700">
            {/* Image Preview Gallery */}
            {selectedSpace.images && selectedSpace.images.length > 0 && (
              <div className="h-52 rounded-xl overflow-hidden bg-slate-100">
                <img
                  src={selectedSpace.images[0]}
                  alt={selectedSpace.title}
                  className="w-full h-full object-cover"
                />
              </div>
            )}

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">LOCATION & OWNER</label>
                <p className="font-bold text-slate-900">{selectedSpace.title}</p>
                <p className="text-slate-500 mt-0.5">{selectedSpace.address}</p>
                <p className="text-[11px] text-purple-600 font-semibold mt-1">
                  Owner UID: {selectedSpace.ownerId}
                </p>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">CAPACITY & SPECS</label>
                <p className="font-bold text-slate-900">
                  Total Capacity: {selectedSpace.totalSlots} Slots
                </p>
                <p className="text-slate-500 mt-0.5">Available Slots: {selectedSpace.availableSlots}</p>
                <p className="text-emerald-600 font-bold mt-1">
                  {selectedSpace.isEvCharging ? '⚡ EV Charging Station Installed' : 'Standard Parking Spot'}
                </p>
              </div>
            </div>

            {/* Pricing Matrix */}
            <div>
              <label className="text-[11px] font-bold text-slate-400 block mb-2">TARIFF PRICING SCHEDULE</label>
              <div className="grid grid-cols-4 gap-2">
                <div className="p-2.5 bg-slate-50 border border-slate-100 rounded-xl text-center">
                  <span className="text-[10px] text-slate-400 font-bold block">HOURLY</span>
                  <span className="font-extrabold text-slate-900">₹{selectedSpace.pricing.hourly}</span>
                </div>
                <div className="p-2.5 bg-slate-50 border border-slate-100 rounded-xl text-center">
                  <span className="text-[10px] text-slate-400 font-bold block">DAILY PASS</span>
                  <span className="font-extrabold text-slate-900">₹{selectedSpace.pricing.daily}</span>
                </div>
                <div className="p-2.5 bg-slate-50 border border-slate-100 rounded-xl text-center">
                  <span className="text-[10px] text-slate-400 font-bold block">WEEKLY PASS</span>
                  <span className="font-extrabold text-slate-900">₹{selectedSpace.pricing.weekly}</span>
                </div>
                <div className="p-2.5 bg-slate-50 border border-slate-100 rounded-xl text-center">
                  <span className="text-[10px] text-slate-400 font-bold block">MONTHLY PASS</span>
                  <span className="font-extrabold text-slate-900">₹{selectedSpace.pricing.monthly}</span>
                </div>
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                onClick={() => setSelectedSpace(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Reject Space Modal */}
      {rejectModalSpace && (
        <Modal
          isOpen={Boolean(rejectModalSpace)}
          onClose={() => setRejectModalSpace(null)}
          title="Reject Parking Space Listing"
          subtitle={`Rejecting listing for ${rejectModalSpace.title}`}
        >
          <div className="space-y-4 text-xs">
            <div className="p-3.5 bg-rose-50 border border-rose-100 rounded-xl flex items-center gap-3 text-rose-800">
              <AlertTriangle className="w-5 h-5 shrink-0" />
              <p>The space will be marked as rejected and disabled from customer map search.</p>
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Reason for Rejection</label>
              <textarea
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                rows={3}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
              />
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setRejectModalSpace(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleExecuteReject}
                disabled={isProcessing}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white font-bold rounded-xl text-xs shadow-sm"
              >
                {isProcessing ? 'Rejecting...' : 'Confirm Rejection'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
