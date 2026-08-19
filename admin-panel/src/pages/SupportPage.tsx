import React, { useEffect, useState } from 'react';
import {
  Headphones,
  Search,
  CheckCircle2,
  AlertCircle,
  Clock,
  MessageSquare,
  Wallet,
  User,
  Send,
  Plus,
  RotateCcw,
} from 'lucide-react';
import { StatusBadge } from '../components/common/StatusBadge';
import { Modal } from '../components/common/Modal';
import { FirebaseAdminService } from '../services/firebaseService';
import { SupportTicket } from '../types';

export const SupportPage: React.FC = () => {
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'open' | 'resolved' | 'all'>('open');
  const [selectedTicket, setSelectedTicket] = useState<SupportTicket | null>(null);
  const [newTicketModal, setNewTicketModal] = useState(false);
  const [resolutionNotes, setResolutionNotes] = useState('');
  const [refundAmount, setRefundAmount] = useState<number>(0);
  const [isProcessing, setIsProcessing] = useState(false);

  // New ticket form
  const [newSubject, setNewSubject] = useState('');
  const [newUserName, setNewUserName] = useState('');
  const [newUserId, setNewUserId] = useState('');
  const [newCategory, setNewCategory] = useState<'booking' | 'payment' | 'space' | 'account' | 'general'>('booking');
  const [newPriority, setNewPriority] = useState<'low' | 'medium' | 'high' | 'urgent'>('high');
  const [newDesc, setNewDesc] = useState('');

  useEffect(() => {
    const unsub = FirebaseAdminService.subscribeSupportTickets(setTickets);
    return () => unsub();
  }, []);

  const filteredTickets = tickets.filter((t) => {
    const query = searchQuery.toLowerCase().trim();
    const matchesSearch =
      t.subject.toLowerCase().includes(query) ||
      t.userName.toLowerCase().includes(query) ||
      t.id.toLowerCase().includes(query) ||
      t.description.toLowerCase().includes(query);

    if (statusFilter === 'open') return matchesSearch && (t.status === 'open' || t.status === 'in_progress');
    if (statusFilter === 'resolved') return matchesSearch && (t.status === 'resolved' || t.status === 'closed');
    return matchesSearch;
  });

  const handleResolveTicket = async () => {
    if (!selectedTicket) return;
    setIsProcessing(true);
    try {
      // 1. If refund amount entered and user ID present, issue credit
      if (refundAmount > 0 && selectedTicket.userId) {
        await FirebaseAdminService.adjustUserWallet(
          selectedTicket.userId,
          refundAmount,
          'credit',
          'Support Dispute Resolution',
          `Compensation for Ticket #${selectedTicket.id.slice(-6)}: ${selectedTicket.subject}`
        );
      }

      // 2. Mark ticket resolved
      await FirebaseAdminService.updateTicketStatus(
        selectedTicket.id,
        'resolved',
        resolutionNotes || 'Resolved by Super Administrator'
      );

      setSelectedTicket(null);
      setRefundAmount(0);
      setResolutionNotes('');
    } catch (e) {
      console.error('Resolve ticket error:', e);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleCreateNewTicket = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newSubject || !newUserName) return;
    setIsProcessing(true);
    try {
      await FirebaseAdminService.createSupportTicket({
        userId: newUserId || 'user_guest',
        userName: newUserName,
        subject: newSubject,
        description: newDesc,
        category: newCategory,
        status: 'open',
        priority: newPriority,
        createdAt: new Date().toISOString(),
      });
      setNewTicketModal(false);
      setNewSubject('');
      setNewUserName('');
      setNewUserId('');
      setNewDesc('');
    } catch (e) {
      console.error('Create ticket error:', e);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Filter Bar */}
      <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search tickets by Subject, User, ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-10 pr-4 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
          />
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600">
            {[
              { id: 'open', label: 'Open Issues' },
              { id: 'resolved', label: 'Resolved Tickets' },
              { id: 'all', label: 'All Tickets' },
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

          <button
            onClick={() => setNewTicketModal(true)}
            className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white font-bold rounded-xl text-xs flex items-center gap-1.5 shadow-sm transition-colors"
          >
            <Plus className="w-4 h-4" /> Create Ticket
          </button>
        </div>
      </div>

      {/* Tickets List / Table */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/75 border-b border-slate-100 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                <th className="py-3.5 px-6">Ticket Subject</th>
                <th className="py-3.5 px-6">User Details</th>
                <th className="py-3.5 px-6">Category</th>
                <th className="py-3.5 px-6">Priority</th>
                <th className="py-3.5 px-6">Status</th>
                <th className="py-3.5 px-6 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-xs text-slate-700">
              {filteredTickets.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-16 text-center text-slate-400">
                    No tickets found in this section.
                  </td>
                </tr>
              ) : (
                filteredTickets.map((ticket) => {
                  return (
                    <tr key={ticket.id} className="hover:bg-slate-50/70 transition-colors">
                      {/* Subject */}
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div className="p-2.5 rounded-xl bg-purple-50 text-purple-700 font-bold shrink-0">
                            <Headphones className="w-4 h-4" />
                          </div>
                          <div>
                            <span className="font-bold text-slate-900 block text-sm">
                              {ticket.subject}
                            </span>
                            <span className="text-[11px] text-slate-400 line-clamp-1 max-w-sm">
                              {ticket.description}
                            </span>
                          </div>
                        </div>
                      </td>

                      {/* User */}
                      <td className="py-4 px-6 font-medium">
                        <div className="text-slate-900 font-bold">{ticket.userName}</div>
                        <div className="text-[11px] text-slate-400 font-mono">
                          {ticket.userId.substring(0, 10)}...
                        </div>
                      </td>

                      {/* Category */}
                      <td className="py-4 px-6">
                        <span className="capitalize px-2.5 py-1 bg-slate-100 text-slate-700 rounded-md font-semibold text-[11px]">
                          {ticket.category}
                        </span>
                      </td>

                      {/* Priority */}
                      <td className="py-4 px-6">
                        <span
                          className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                            ticket.priority === 'urgent' || ticket.priority === 'high'
                              ? 'bg-rose-100 text-rose-700 font-extrabold'
                              : 'bg-slate-100 text-slate-600'
                          }`}
                        >
                          {ticket.priority.toUpperCase()}
                        </span>
                      </td>

                      {/* Status */}
                      <td className="py-4 px-6">
                        <StatusBadge status={ticket.status} />
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-6 text-right whitespace-nowrap">
                        <button
                          onClick={() => {
                            setSelectedTicket(ticket);
                            setResolutionNotes(ticket.resolutionNotes || '');
                          }}
                          className="px-3 py-1.5 bg-slate-100 hover:bg-purple-50 hover:text-purple-700 text-slate-700 font-bold rounded-xl text-xs inline-flex items-center gap-1 transition-colors"
                        >
                          <MessageSquare className="w-3.5 h-3.5" /> Resolve Issue
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Ticket Details & Resolution Modal */}
      {selectedTicket && (
        <Modal
          isOpen={Boolean(selectedTicket)}
          onClose={() => setSelectedTicket(null)}
          title={`Ticket #${selectedTicket.id.slice(-6).toUpperCase()}: ${selectedTicket.subject}`}
          subtitle={`Submitted by ${selectedTicket.userName}`}
        >
          <div className="space-y-5 text-xs text-slate-700">
            <div className="p-4 bg-slate-50 rounded-xl border border-slate-100 space-y-2">
              <div className="flex justify-between">
                <span className="font-bold text-slate-400 uppercase text-[10px]">CATEGORY & PRIORITY</span>
                <span className="font-bold text-slate-900 capitalize">
                  {selectedTicket.category} • Priority {selectedTicket.priority}
                </span>
              </div>
              <p className="text-slate-800 text-xs leading-relaxed pt-1 border-t border-slate-200">
                {selectedTicket.description}
              </p>
            </div>

            {/* Compensation / Wallet Credit section */}
            <div className="p-4 bg-purple-50/60 rounded-xl border border-purple-100 space-y-3">
              <div className="flex items-center gap-2 font-bold text-purple-900">
                <Wallet className="w-4 h-4 text-purple-700" />
                <span>Issue Customer Compensation (Optional Wallet Credit)</span>
              </div>
              <p className="text-slate-500 text-[11px]">
                Enter an amount to immediately credit the user's Mee Parking wallet balance upon resolving this dispute.
              </p>
              <div className="flex items-center gap-3">
                <span className="font-bold text-slate-700">Credit Amount: ₹</span>
                <input
                  type="number"
                  value={refundAmount}
                  onChange={(e) => setRefundAmount(Number(e.target.value))}
                  min={0}
                  placeholder="0"
                  className="w-32 bg-white border border-slate-200 rounded-lg p-2 text-xs font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                />
              </div>
            </div>

            {/* Resolution Note */}
            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Administrative Resolution Notes</label>
              <textarea
                value={resolutionNotes}
                onChange={(e) => setResolutionNotes(e.target.value)}
                rows={3}
                placeholder="Explain the actions taken to resolve this ticket..."
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
              />
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setSelectedTicket(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Close
              </button>
              <button
                type="button"
                onClick={handleResolveTicket}
                disabled={isProcessing}
                className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs flex items-center gap-1.5 shadow-sm"
              >
                <CheckCircle2 className="w-4 h-4" />
                {isProcessing ? 'Resolving Ticket...' : 'Mark as Resolved'}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Create Ticket Modal */}
      {newTicketModal && (
        <Modal
          isOpen={newTicketModal}
          onClose={() => setNewTicketModal(false)}
          title="Create New Support / Dispute Ticket"
          subtitle="Manually file an internal support case"
        >
          <form onSubmit={handleCreateNewTicket} className="space-y-4 text-xs">
            <div>
              <label className="font-bold text-slate-700 block mb-1.5">User / Customer Name *</label>
              <input
                type="text"
                required
                value={newUserName}
                onChange={(e) => setNewUserName(e.target.value)}
                placeholder="Customer or Partner Name"
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:border-purple-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">User ID (Optional)</label>
              <input
                type="text"
                value={newUserId}
                onChange={(e) => setNewUserId(e.target.value)}
                placeholder="Firebase User UID"
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:border-purple-500"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="font-bold text-slate-700 block mb-1.5">Category</label>
                <select
                  value={newCategory}
                  onChange={(e) => setNewCategory(e.target.value as any)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:border-purple-500 font-semibold"
                >
                  <option value="booking">Booking Issue</option>
                  <option value="payment">Payment / Refund</option>
                  <option value="space">Space Occupied / Blocked</option>
                  <option value="account">Account Access</option>
                  <option value="general">General Inquiry</option>
                </select>
              </div>

              <div>
                <label className="font-bold text-slate-700 block mb-1.5">Priority</label>
                <select
                  value={newPriority}
                  onChange={(e) => setNewPriority(e.target.value as any)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:border-purple-500 font-semibold"
                >
                  <option value="low">Low</option>
                  <option value="medium">Medium</option>
                  <option value="high">High</option>
                  <option value="urgent">Urgent</option>
                </select>
              </div>
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Subject *</label>
              <input
                type="text"
                required
                value={newSubject}
                onChange={(e) => setNewSubject(e.target.value)}
                placeholder="Brief summary of the issue..."
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:border-purple-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Detailed Description</label>
              <textarea
                value={newDesc}
                onChange={(e) => setNewDesc(e.target.value)}
                rows={3}
                placeholder="Full context..."
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:border-purple-500"
              />
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setNewTicketModal(false)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isProcessing}
                className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white font-bold rounded-xl text-xs shadow-sm"
              >
                {isProcessing ? 'Creating...' : 'Submit Ticket'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
};
