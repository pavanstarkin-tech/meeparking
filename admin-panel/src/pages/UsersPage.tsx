import React, { useEffect, useState } from 'react';
import {
  Search,
  Users,
  Car,
  Bike,
  Wallet,
  ShieldAlert,
  ShieldCheck,
  PlusCircle,
  MinusCircle,
  Eye,
  CheckCircle2,
  XCircle,
} from 'lucide-react';
import { StatusBadge } from '../components/common/StatusBadge';
import { Modal } from '../components/common/Modal';
import { FirebaseAdminService } from '../services/firebaseService';
import { UserProfile } from '../types';

export const UsersPage: React.FC = () => {
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState<'all' | 'user' | 'partner'>('user');
  const [selectedUser, setSelectedUser] = useState<UserProfile | null>(null);
  const [walletModalUser, setWalletModalUser] = useState<UserProfile | null>(null);
  const [walletAmount, setWalletAmount] = useState<number>(100);
  const [walletType, setWalletType] = useState<'credit' | 'debit'>('credit');
  const [walletReason, setWalletReason] = useState('Promotional Bonus / Admin Credit');
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    const unsub = FirebaseAdminService.subscribeUsers(setUsers);
    return () => unsub();
  }, []);

  const filteredUsers = users.filter((u) => {
    const query = searchQuery.toLowerCase().trim();
    const matchesSearch =
      u.name.toLowerCase().includes(query) ||
      u.email.toLowerCase().includes(query) ||
      u.phone.toLowerCase().includes(query) ||
      u.uid.toLowerCase().includes(query);

    const matchesRole =
      roleFilter === 'all' || u.role.toLowerCase() === roleFilter.toLowerCase();

    return matchesSearch && matchesRole;
  });

  const handleToggleStatus = async (user: UserProfile) => {
    const newStatus = user.status === 'suspended' ? 'active' : 'suspended';
    await FirebaseAdminService.updateUserStatus(user.uid, newStatus);
  };

  const handleExecuteWalletAdjust = async () => {
    if (!walletModalUser) return;
    setIsProcessing(true);
    try {
      await FirebaseAdminService.adjustUserWallet(
        walletModalUser.uid,
        walletAmount,
        walletType,
        walletType === 'credit' ? 'Wallet Top-up' : 'Wallet Debit',
        walletReason
      );
      setWalletModalUser(null);
    } catch (e) {
      console.error('Wallet adjust error:', e);
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
            placeholder="Search by Name, Email, Phone, UID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-10 pr-4 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
          />
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600">
            {[
              { id: 'user', label: 'Drivers (Seekers)' },
              { id: 'partner', label: 'Space Owners' },
              { id: 'all', label: 'All Accounts' },
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setRoleFilter(tab.id as any)}
                className={`px-3 py-1 rounded-lg capitalize transition-all ${
                  roleFilter === tab.id
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

      {/* Users Data Table */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/75 border-b border-slate-100 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                <th className="py-3.5 px-6">User Profile</th>
                <th className="py-3.5 px-6">Role & Status</th>
                <th className="py-3.5 px-6">Contact Info</th>
                <th className="py-3.5 px-6">Registered Vehicles</th>
                <th className="py-3.5 px-6">Wallet Balance</th>
                <th className="py-3.5 px-6 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-xs text-slate-700">
              {filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-16 text-center text-slate-400">
                    No accounts matching your query found.
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user) => {
                  const initial = user.name ? user.name.substring(0, 1).toUpperCase() : 'U';
                  const vehicles = user.vehicles || [];

                  return (
                    <tr key={user.uid} className="hover:bg-slate-50/70 transition-colors">
                      {/* Avatar & Name */}
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-full bg-purple-100 text-purple-700 font-bold flex items-center justify-center shrink-0 border border-purple-200 overflow-hidden">
                            {user.photoUrl ? (
                              <img src={user.photoUrl} alt={user.name} className="w-full h-full object-cover" />
                            ) : (
                              initial
                            )}
                          </div>
                          <div>
                            <span className="font-bold text-slate-900 block text-sm">
                              {user.name || 'Anonymous User'}
                            </span>
                            <span className="text-[10px] text-slate-400 font-mono">
                              {user.uid.substring(0, 12)}...
                            </span>
                          </div>
                        </div>
                      </td>

                      {/* Role & Status */}
                      <td className="py-4 px-6 space-y-1">
                        <div>
                          <StatusBadge status={user.role} />
                        </div>
                        <span
                          className={`text-[10px] font-bold px-2 py-0.5 rounded-full inline-block ${
                            user.status === 'suspended'
                              ? 'bg-rose-100 text-rose-700'
                              : 'bg-emerald-100 text-emerald-700'
                          }`}
                        >
                          {user.status === 'suspended' ? 'Suspended' : 'Active Account'}
                        </span>
                      </td>

                      {/* Contact */}
                      <td className="py-4 px-6 font-medium">
                        <div className="text-slate-900">{user.email || 'No email provided'}</div>
                        <div className="text-[11px] text-slate-500 mt-0.5">{user.phone || 'No phone'}</div>
                      </td>

                      {/* Vehicles */}
                      <td className="py-4 px-6">
                        {vehicles.length === 0 ? (
                          <span className="text-slate-400 italic text-[11px]">No vehicles added</span>
                        ) : (
                          <div className="flex flex-wrap gap-1.5 max-w-[200px]">
                            {vehicles.map((v, i) => (
                              <span
                                key={i}
                                className="inline-flex items-center gap-1 bg-slate-100 text-slate-700 px-2 py-0.5 rounded-md text-[10px] font-bold"
                              >
                                {v.type?.toLowerCase().includes('2') ? (
                                  <Bike className="w-3 h-3 text-emerald-600" />
                                ) : (
                                  <Car className="w-3 h-3 text-purple-600" />
                                )}
                                {v.number}
                              </span>
                            ))}
                          </div>
                        )}
                      </td>

                      {/* Wallet Balance */}
                      <td className="py-4 px-6">
                        <span className="font-extrabold text-slate-900 text-sm">
                          ₹{user.walletBalance.toFixed(2)}
                        </span>
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-6 text-right space-x-2 whitespace-nowrap">
                        <button
                          onClick={() => setSelectedUser(user)}
                          title="View Details"
                          className="p-1.5 text-slate-500 hover:text-purple-700 hover:bg-purple-50 rounded-lg transition-colors"
                        >
                          <Eye className="w-4 h-4" />
                        </button>

                        <button
                          onClick={() => {
                            setWalletModalUser(user);
                            setWalletAmount(100);
                            setWalletType('credit');
                          }}
                          title="Adjust Wallet Balance"
                          className="p-1.5 text-slate-500 hover:text-emerald-700 hover:bg-emerald-50 rounded-lg transition-colors"
                        >
                          <Wallet className="w-4 h-4" />
                        </button>

                        <button
                          onClick={() => handleToggleStatus(user)}
                          title={user.status === 'suspended' ? 'Re-activate Account' : 'Suspend Account'}
                          className={`p-1.5 rounded-lg transition-colors ${
                            user.status === 'suspended'
                              ? 'text-emerald-600 hover:bg-emerald-50'
                              : 'text-rose-600 hover:bg-rose-50'
                          }`}
                        >
                          {user.status === 'suspended' ? (
                            <CheckCircle2 className="w-4 h-4" />
                          ) : (
                            <ShieldAlert className="w-4 h-4" />
                          )}
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

      {/* User Details Modal */}
      {selectedUser && (
        <Modal
          isOpen={Boolean(selectedUser)}
          onClose={() => setSelectedUser(null)}
          title={`User Profile: ${selectedUser.name}`}
          subtitle={`Account ID: ${selectedUser.uid}`}
        >
          <div className="space-y-6 text-xs text-slate-700">
            <div className="flex items-center gap-4 p-4 rounded-xl bg-purple-50/70 border border-purple-100">
              <div className="w-14 h-14 rounded-full bg-purple-200 text-purple-800 font-bold text-xl flex items-center justify-center shrink-0 overflow-hidden">
                {selectedUser.photoUrl ? (
                  <img src={selectedUser.photoUrl} alt={selectedUser.name} className="w-full h-full object-cover" />
                ) : (
                  selectedUser.name.substring(0, 1).toUpperCase()
                )}
              </div>
              <div className="flex-1">
                <h4 className="text-base font-bold text-slate-900">{selectedUser.name}</h4>
                <p className="text-slate-500">{selectedUser.email || selectedUser.phone}</p>
                <div className="flex gap-2 mt-2">
                  <StatusBadge status={selectedUser.role} />
                  <span className="font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200 text-[10px]">
                    Wallet: ₹{selectedUser.walletBalance.toFixed(2)}
                  </span>
                </div>
              </div>
            </div>

            {/* Vehicles List */}
            <div>
              <h5 className="font-bold text-slate-900 uppercase tracking-wider text-[11px] mb-2">
                Registered Vehicles ({selectedUser.vehicles?.length || 0})
              </h5>
              {selectedUser.vehicles && selectedUser.vehicles.length > 0 ? (
                <div className="grid grid-cols-2 gap-3">
                  {selectedUser.vehicles.map((v, i) => (
                    <div key={i} className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                      <p className="font-bold text-slate-900">{v.number}</p>
                      <p className="text-slate-500 text-[11px]">
                        {v.model} ({v.type})
                      </p>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-slate-400 italic">No vehicles registered yet.</p>
              )}
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                onClick={() => setSelectedUser(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Adjust Wallet Balance Modal */}
      {walletModalUser && (
        <Modal
          isOpen={Boolean(walletModalUser)}
          onClose={() => setWalletModalUser(null)}
          title={`Adjust Wallet Balance: ${walletModalUser.name}`}
          subtitle={`Current Balance: ₹${walletModalUser.walletBalance.toFixed(2)}`}
        >
          <div className="space-y-4 text-xs">
            <div className="flex gap-3">
              <button
                type="button"
                onClick={() => setWalletType('credit')}
                className={`flex-1 py-2.5 rounded-xl font-bold flex items-center justify-center gap-2 border transition-all ${
                  walletType === 'credit'
                    ? 'bg-emerald-50 text-emerald-700 border-emerald-300 shadow-sm'
                    : 'bg-slate-50 text-slate-600 border-slate-200'
                }`}
              >
                <PlusCircle className="w-4 h-4" /> Credit (Add Funds)
              </button>

              <button
                type="button"
                onClick={() => setWalletType('debit')}
                className={`flex-1 py-2.5 rounded-xl font-bold flex items-center justify-center gap-2 border transition-all ${
                  walletType === 'debit'
                    ? 'bg-rose-50 text-rose-700 border-rose-300 shadow-sm'
                    : 'bg-slate-50 text-slate-600 border-slate-200'
                }`}
              >
                <MinusCircle className="w-4 h-4" /> Debit (Deduct Funds)
              </button>
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Amount (₹)</label>
              <input
                type="number"
                value={walletAmount}
                onChange={(e) => setWalletAmount(Number(e.target.value))}
                min={1}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 font-bold focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Reason / Note</label>
              <input
                type="text"
                value={walletReason}
                onChange={(e) => setWalletReason(e.target.value)}
                placeholder="Reason for adjustment..."
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
              />
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setWalletModalUser(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleExecuteWalletAdjust}
                disabled={isProcessing}
                className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white font-bold rounded-xl text-xs shadow-sm"
              >
                {isProcessing ? 'Updating Wallet...' : `Confirm ${walletType === 'credit' ? 'Credit' : 'Debit'}`}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
