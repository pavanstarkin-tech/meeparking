import React, { useEffect, useState } from 'react';
import {
  Building2,
  Search,
  CheckCircle2,
  XCircle,
  Clock,
  ShieldCheck,
  ShieldAlert,
  CreditCard,
  Phone,
  Mail,
  MapPin,
  Eye,
  AlertTriangle,
} from 'lucide-react';
import { StatusBadge } from '../components/common/StatusBadge';
import { Modal } from '../components/common/Modal';
import { FirebaseAdminService } from '../services/firebaseService';
import { UserProfile, ParkingSpace } from '../types';

export const PartnersPage: React.FC = () => {
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [spaces, setSpaces] = useState<ParkingSpace[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'pending' | 'active' | 'all' | 'suspended'>('all');
  const [selectedPartner, setSelectedPartner] = useState<UserProfile | null>(null);
  const [rejectModalPartner, setRejectModalPartner] = useState<UserProfile | null>(null);
  const [rejectionReason, setRejectionReason] = useState('Incomplete KYC / Identity Verification Failed');
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    const unsubUsers = FirebaseAdminService.subscribeUsers(setUsers);
    const unsubSpaces = FirebaseAdminService.subscribeParkingSpaces(setSpaces);
    return () => {
      unsubUsers();
      unsubSpaces();
    };
  }, []);

  const partners = users.filter((u) => u.role === 'partner');

  const filteredPartners = partners.filter((p) => {
    const query = searchQuery.toLowerCase().trim();
    const matchesSearch =
      p.name.toLowerCase().includes(query) ||
      (p.businessName && p.businessName.toLowerCase().includes(query)) ||
      p.email.toLowerCase().includes(query) ||
      p.phone.toLowerCase().includes(query) ||
      p.uid.toLowerCase().includes(query);

    if (statusFilter === 'pending') {
      return matchesSearch && (!p.isApproved || p.status === 'pending');
    }
    if (statusFilter === 'active') {
      return matchesSearch && p.isApproved && p.status !== 'suspended';
    }
    if (statusFilter === 'suspended') {
      return matchesSearch && p.status === 'suspended';
    }
    return matchesSearch;
  });

  const handleApprovePartner = async (uid: string) => {
    setIsProcessing(true);
    try {
      await FirebaseAdminService.approvePartner(uid);
    } catch (e) {
      console.error('Approval error:', e);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleExecuteReject = async () => {
    if (!rejectModalPartner) return;
    setIsProcessing(true);
    try {
      await FirebaseAdminService.rejectPartner(rejectModalPartner.uid, rejectionReason);
      setRejectModalPartner(null);
    } catch (e) {
      console.error('Rejection error:', e);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Information Banner */}
      <div className="bg-white border border-purple-100 rounded-2xl p-5 shadow-sm flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <span className="bg-purple-100 text-purple-700 text-[10px] font-extrabold uppercase px-2.5 py-0.5 rounded-full">
              Partner Hub
            </span>
            <h3 className="font-extrabold text-sm text-slate-900">Auto-Approved Partner Accounts</h3>
          </div>
          <p className="text-xs text-slate-500 max-w-2xl leading-relaxed">
            Partner accounts are automatically approved upon registration so hosts can immediately set up their profiles and submit parking spaces. Their submitted parking slots require Admin approval under <strong>Listings Review</strong> before going live.
          </p>
        </div>

        <a
          href="/listings"
          className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-xl text-xs font-bold shadow-md shadow-purple-600/20 transition-all shrink-0"
        >
          Review Pending Listings →
        </a>
      </div>

      {/* Search & Tabs */}
      <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by Business Name, Partner, Phone..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-10 pr-4 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
          />
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600">
            {[
              { id: 'all', label: 'All Partners' },
              { id: 'active', label: 'Active Partners' },
              { id: 'pending', label: 'Manual Review' },
              { id: 'suspended', label: 'Suspended' },
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

      {/* Partners Grid */}
      {filteredPartners.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-100 p-16 text-center text-slate-400 shadow-sm">
          <Building2 className="w-10 h-10 mx-auto text-slate-300 mb-3" />
          <p className="font-bold text-slate-700">No partner accounts found</p>
          <p className="text-xs text-slate-400 mt-1">Try selecting another filter or searching a different keyword.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredPartners.map((partner) => {
            const ownedSpaces = spaces.filter((s) => s.ownerId === partner.uid);
            const isPending = !partner.isApproved || partner.status === 'pending';

            return (
              <div
                key={partner.uid}
                className={`bg-white rounded-2xl border transition-all duration-200 p-6 flex flex-col justify-between shadow-sm hover:shadow-md ${
                  isPending ? 'border-amber-200 bg-amber-50/10' : 'border-slate-100'
                }`}
              >
                <div>
                  {/* Card Header */}
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <div className="w-12 h-12 rounded-2xl bg-purple-100 text-purple-700 font-extrabold text-lg flex items-center justify-center shrink-0 overflow-hidden border border-purple-200">
                        {partner.photoUrl ? (
                          <img src={partner.photoUrl} alt={partner.name} className="w-full h-full object-cover" />
                        ) : (
                          partner.name.substring(0, 1).toUpperCase()
                        )}
                      </div>
                      <div>
                        <h4 className="font-bold text-slate-900 text-sm leading-tight">
                          {partner.businessName || partner.name}
                        </h4>
                        <p className="text-xs text-slate-500 font-medium">{partner.name}</p>
                      </div>
                    </div>

                    <span
                      className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${
                        isPending
                          ? 'bg-amber-50 text-amber-700 border-amber-200'
                          : partner.status === 'suspended'
                          ? 'bg-rose-50 text-rose-700 border-rose-200'
                          : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                      }`}
                    >
                      {isPending ? 'Pending KYC' : partner.status === 'suspended' ? 'Suspended' : 'Verified Partner'}
                    </span>
                  </div>

                  {/* Contact Info */}
                  <div className="mt-4 space-y-1.5 text-xs text-slate-600 bg-slate-50 p-3 rounded-xl border border-slate-100">
                    <div className="flex items-center gap-2">
                      <Phone className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                      <span>{partner.phone || 'No phone provided'}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <Mail className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                      <span className="truncate">{partner.email || 'No email provided'}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <CreditCard className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                      <span className="font-mono text-[11px]">
                        {partner.bankDetails?.accountNumber
                          ? `A/C: •••• ${partner.bankDetails.accountNumber.slice(-4)} (${partner.bankDetails.ifscCode || 'IFSC'})`
                          : 'Bank details pending'}
                      </span>
                    </div>
                  </div>

                  {/* Space Count Badge */}
                  <div className="mt-4 flex items-center justify-between text-xs font-semibold text-slate-500">
                    <span>Listed Properties:</span>
                    <span className="font-bold text-slate-900 bg-purple-50 text-purple-700 px-2 py-0.5 rounded-md">
                      {ownedSpaces.length} Parking Spaces
                    </span>
                  </div>
                </div>

                {/* Actions Footer */}
                <div className="mt-6 pt-4 border-t border-slate-100 flex items-center gap-2">
                  <button
                    onClick={() => setSelectedPartner(partner)}
                    className="flex-1 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors"
                  >
                    <Eye className="w-3.5 h-3.5" /> Details
                  </button>

                  {isPending ? (
                    <>
                      <button
                        onClick={() => handleApprovePartner(partner.uid)}
                        disabled={isProcessing}
                        className="flex-1 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 shadow-sm transition-colors"
                      >
                        <CheckCircle2 className="w-3.5 h-3.5" /> Approve
                      </button>
                      <button
                        onClick={() => setRejectModalPartner(partner)}
                        className="py-2 px-3 bg-rose-50 hover:bg-rose-100 text-rose-700 font-bold rounded-xl text-xs transition-colors"
                        title="Reject Application"
                      >
                        <XCircle className="w-4 h-4" />
                      </button>
                    </>
                  ) : (
                    <button
                      onClick={() =>
                        FirebaseAdminService.updateUserStatus(
                          partner.uid,
                          partner.status === 'suspended' ? 'active' : 'suspended'
                        )
                      }
                      className={`flex-1 py-2 font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors ${
                        partner.status === 'suspended'
                          ? 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                          : 'bg-rose-50 text-rose-700 hover:bg-rose-100'
                      }`}
                    >
                      {partner.status === 'suspended' ? 'Re-Activate' : 'Suspend Partner'}
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Partner Details Modal */}
      {selectedPartner && (
        <Modal
          isOpen={Boolean(selectedPartner)}
          onClose={() => setSelectedPartner(null)}
          title={`Partner Profile: ${selectedPartner.businessName || selectedPartner.name}`}
          subtitle={`UID: ${selectedPartner.uid}`}
        >
          <div className="space-y-6 text-xs text-slate-700">
            <div className="p-4 rounded-xl bg-purple-50 border border-purple-100 flex items-center justify-between">
              <div>
                <span className="text-[11px] font-bold text-purple-700 block">Verification Status</span>
                <span className="text-base font-extrabold text-slate-900">
                  {selectedPartner.isApproved ? 'Verified Partner Account' : 'Pending Administrative Review'}
                </span>
              </div>
              <StatusBadge status={selectedPartner.status || 'active'} />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">BUSINESS / OWNER NAME</label>
                <p className="font-bold text-slate-900">{selectedPartner.businessName || 'Individual Host'}</p>
                <p className="text-slate-500 mt-0.5">{selectedPartner.name}</p>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">CONTACT DETAILS</label>
                <p className="font-bold text-slate-900">{selectedPartner.phone}</p>
                <p className="text-slate-500 mt-0.5">{selectedPartner.email}</p>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">BANK DISBURSEMENT INFO</label>
                <p className="font-mono text-slate-900 font-bold">
                  A/C: {selectedPartner.bankDetails?.accountNumber || 'Not submitted'}
                </p>
                <p className="text-slate-500 mt-0.5">
                  IFSC: {selectedPartner.bankDetails?.ifscCode || 'N/A'} • {selectedPartner.bankDetails?.bankName || ''}
                </p>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">WALLET & EARNINGS</label>
                <p className="font-extrabold text-purple-700 text-sm">
                  ₹{selectedPartner.walletBalance?.toFixed(2) || '0.00'}
                </p>
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                onClick={() => setSelectedPartner(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Reject Partner Application Modal */}
      {rejectModalPartner && (
        <Modal
          isOpen={Boolean(rejectModalPartner)}
          onClose={() => setRejectModalPartner(null)}
          title="Reject Partner Application"
          subtitle={`Rejecting registration for ${rejectModalPartner.businessName || rejectModalPartner.name}`}
        >
          <div className="space-y-4 text-xs">
            <div className="p-3.5 bg-rose-50 border border-rose-100 rounded-xl flex items-center gap-3 text-rose-800">
              <AlertTriangle className="w-5 h-5 shrink-0" />
              <p>
                The host will be marked as unverified and will not be able to list parking spaces on the Mee Parking mobile app.
              </p>
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Reason for Rejection / Missing Documents</label>
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
                onClick={() => setRejectModalPartner(null)}
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
