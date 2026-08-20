import React, { useEffect, useState } from 'react';
import {
  BadgePercent,
  Search,
  CheckCircle2,
  XCircle,
  CreditCard,
  Building,
  ArrowDownRight,
  TrendingUp,
  DollarSign,
  Clock,
  Send,
} from 'lucide-react';
import { StatCard } from '../components/common/StatCard';
import { StatusBadge } from '../components/common/StatusBadge';
import { Modal } from '../components/common/Modal';
import { FirebaseAdminService } from '../services/firebaseService';
import { PayoutRequest, Booking } from '../types';

export const PayoutsPage: React.FC = () => {
  const [payouts, setPayouts] = useState<PayoutRequest[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'pending' | 'processed' | 'all'>('pending');
  const [selectedPayout, setSelectedPayout] = useState<PayoutRequest | null>(null);
  const [disburseModalPayout, setDisburseModalPayout] = useState<PayoutRequest | null>(null);
  const [refNumber, setRefNumber] = useState('');
  const [disburseNotes, setDisburseNotes] = useState('Disbursed via Direct Bank NEFT / IMPS');
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    const unsubPayouts = FirebaseAdminService.subscribePayouts(setPayouts);
    const unsubBookings = FirebaseAdminService.subscribeBookings(setBookings);
    return () => {
      unsubPayouts();
      unsubBookings();
    };
  }, []);

  const totalVolume = bookings
    .filter((b) => b.status === 'completed' || b.status === 'upcoming' || b.status === 'confirmed')
    .reduce((sum, b) => sum + (b.totalAmount || 0), 0);

  const totalDisbursed = payouts
    .filter((p) => p.status === 'processed')
    .reduce((sum, p) => sum + (p.amount || 0), 0);

  const pendingAmount = payouts
    .filter((p) => p.status === 'pending')
    .reduce((sum, p) => sum + (p.amount || 0), 0);

  const platformCommission = Math.round(totalVolume * 0.15); // 15% Platform Take Rate

  const filteredPayouts = payouts.filter((p) => {
    const query = searchQuery.toLowerCase().trim();
    const matchesSearch =
      p.partnerName.toLowerCase().includes(query) ||
      p.id.toLowerCase().includes(query) ||
      p.partnerId.toLowerCase().includes(query) ||
      (p.referenceNumber && p.referenceNumber.toLowerCase().includes(query));

    if (statusFilter === 'pending') return matchesSearch && p.status === 'pending';
    if (statusFilter === 'processed') return matchesSearch && p.status === 'processed';
    return matchesSearch;
  });

  const handleOpenDisburse = (payout: PayoutRequest) => {
    setDisburseModalPayout(payout);
    setRefNumber(`MEE_TXN_${Date.now().toString().slice(-6)}`);
    setDisburseNotes('Direct IMPS Payout to Bank Account');
  };

  const handleExecuteDisburse = async () => {
    if (!disburseModalPayout) return;
    setIsProcessing(true);
    try {
      await FirebaseAdminService.processPayout(disburseModalPayout.id, refNumber, disburseNotes);
      setDisburseModalPayout(null);
    } catch (e) {
      console.error('Disbursement error:', e);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleRejectPayout = async (payoutId: string) => {
    await FirebaseAdminService.rejectPayout(payoutId, 'Bank verification failed / Invalid account details');
  };

  return (
    <div className="space-y-6">
      {/* 4 KPI Financial Overview Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <StatCard
          title="Total Platform GMV"
          value={`₹${totalVolume.toLocaleString('en-IN')}`}
          subtitle="Gross merchandise value"
          icon={DollarSign}
          iconColor="text-purple-600"
          iconBg="bg-purple-50"
        />
        <StatCard
          title="Platform Commission (15%)"
          value={`₹${platformCommission.toLocaleString('en-IN')}`}
          subtitle="Net revenue retained"
          icon={BadgePercent}
          iconColor="text-emerald-600"
          iconBg="bg-emerald-50"
        />
        <StatCard
          title="Total Disbursed"
          value={`₹${totalDisbursed.toLocaleString('en-IN')}`}
          subtitle="Paid out to host bank accounts"
          icon={ArrowDownRight}
          iconColor="text-blue-600"
          iconBg="bg-blue-50"
        />
        <StatCard
          title="Pending Disbursements"
          value={`₹${pendingAmount.toLocaleString('en-IN')}`}
          subtitle={`${payouts.filter((p) => p.status === 'pending').length} pending requests`}
          icon={Clock}
          iconColor="text-amber-600"
          iconBg="bg-amber-50"
        />
      </div>

      {/* Filter Bar */}
      <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by Partner, ID, Reference..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-10 pr-4 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
          />
        </div>

        <div className="flex items-center bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600">
          {[
            { id: 'pending', label: 'Pending Requests' },
            { id: 'processed', label: 'Processed Payouts' },
            { id: 'all', label: 'All History' },
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

      {/* Payouts Table */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/75 border-b border-slate-100 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                <th className="py-3.5 px-6">Partner Details</th>
                <th className="py-3.5 px-6">Amount Requested</th>
                <th className="py-3.5 px-6">Bank Account Info</th>
                <th className="py-3.5 px-6">Requested Date</th>
                <th className="py-3.5 px-6">Status & Ref</th>
                <th className="py-3.5 px-6 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-xs text-slate-700">
              {filteredPayouts.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-16 text-center text-slate-400">
                    No payout requests found for this filter.
                  </td>
                </tr>
              ) : (
                filteredPayouts.map((payout) => {
                  const isPending = payout.status === 'pending';

                  return (
                    <tr key={payout.id} className="hover:bg-slate-50/70 transition-colors">
                      {/* Partner Name & ID */}
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-700 font-bold flex items-center justify-center shrink-0">
                            <Building className="w-5 h-5" />
                          </div>
                          <div>
                            <span className="font-bold text-slate-900 block text-sm">
                              {payout.partnerName}
                            </span>
                            <span className="text-[11px] text-slate-400 font-mono">
                              UID: {payout.partnerId.substring(0, 10)}...
                            </span>
                          </div>
                        </div>
                      </td>

                      {/* Amount */}
                      <td className="py-4 px-6">
                        <span className="font-extrabold text-slate-900 text-base">
                          ₹{payout.amount.toLocaleString('en-IN')}
                        </span>
                      </td>

                      {/* Bank Details */}
                      <td className="py-4 px-6 font-medium">
                        <div className="flex items-center gap-1.5 text-slate-900 font-bold">
                          <CreditCard className="w-3.5 h-3.5 text-slate-400" />
                          <span>
                            {payout.bankDetails?.accountNumber
                              ? `•••• ${payout.bankDetails.accountNumber.slice(-4)}`
                              : 'UPI / Direct'}
                          </span>
                        </div>
                        <div className="text-[11px] text-slate-400 mt-0.5 font-mono">
                          IFSC: {payout.bankDetails?.ifscCode || 'N/A'} • {payout.bankDetails?.bankName || ''}
                        </div>
                      </td>

                      {/* Date */}
                      <td className="py-4 px-6">
                        <span className="text-slate-700 font-medium">{payout.requestedAt}</span>
                      </td>

                      {/* Status */}
                      <td className="py-4 px-6 space-y-1">
                        <div>
                          <StatusBadge status={payout.status} />
                        </div>
                        {payout.referenceNumber && (
                          <span className="text-[10px] text-slate-400 font-mono block">
                            Ref: {payout.referenceNumber}
                          </span>
                        )}
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-6 text-right space-x-2 whitespace-nowrap">
                        {isPending ? (
                          <>
                            <button
                              onClick={() => handleOpenDisburse(payout)}
                              className="px-3 py-1.5 bg-purple-600 hover:bg-purple-700 text-white font-bold rounded-xl text-xs inline-flex items-center gap-1 shadow-sm transition-colors"
                            >
                              <Send className="w-3.5 h-3.5" /> Disburse Funds
                            </button>
                            <button
                              onClick={() => handleRejectPayout(payout.id)}
                              className="p-1.5 text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                              title="Reject Payout"
                            >
                              <XCircle className="w-4 h-4" />
                            </button>
                          </>
                        ) : (
                          <span className="text-emerald-600 font-bold text-xs inline-flex items-center gap-1">
                            <CheckCircle2 className="w-4 h-4" /> Paid
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Disburse Funds Modal */}
      {disburseModalPayout && (
        <Modal
          isOpen={Boolean(disburseModalPayout)}
          onClose={() => setDisburseModalPayout(null)}
          title="Approve & Mark Payout as Disbursed"
          subtitle={`Disbursing ₹${disburseModalPayout.amount} to ${disburseModalPayout.partnerName}`}
        >
          <div className="space-y-4 text-xs">
            <div className="p-4 bg-purple-50 rounded-xl border border-purple-100 space-y-2">
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">Recipient:</span>
                <span className="font-bold text-slate-900">{disburseModalPayout.partnerName}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">Bank A/C:</span>
                <span className="font-mono font-bold text-slate-900">
                  {disburseModalPayout.bankDetails?.accountNumber || 'UPI Payment'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500 font-medium">Net Amount:</span>
                <span className="text-lg font-extrabold text-purple-700">
                  ₹{disburseModalPayout.amount.toLocaleString('en-IN')}
                </span>
              </div>
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Bank / Gateway Reference Number</label>
              <input
                type="text"
                value={refNumber}
                onChange={(e) => setRefNumber(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 font-mono font-bold focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Payment Notes / Method</label>
              <input
                type="text"
                value={disburseNotes}
                onChange={(e) => setDisburseNotes(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
              />
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setDisburseModalPayout(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleExecuteDisburse}
                disabled={isProcessing}
                className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white font-bold rounded-xl text-xs shadow-sm"
              >
                {isProcessing ? 'Recording Payment...' : 'Confirm Disbursement'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
