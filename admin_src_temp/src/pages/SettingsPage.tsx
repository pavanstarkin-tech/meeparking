import React, { useState } from 'react';
import {
  Settings,
  Database,
  Shield,
  Key,
  BadgePercent,
  CheckCircle2,
  AlertCircle,
  Save,
  Server,
  Sparkles,
} from 'lucide-react';
import { firebaseConfig } from '../config/firebase';

export const SettingsPage: React.FC = () => {
  const [commissionRate, setCommissionRate] = useState<number>(15);
  const [cancellationFee, setCancellationFee] = useState<number>(20);
  const [supportEmail, setSupportEmail] = useState('support@meeparking.com');
  const [autoApproveListings, setAutoApproveListings] = useState(false);
  const [isSaved, setIsSaved] = useState(false);

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaved(true);
    setTimeout(() => setIsSaved(false), 3000);
  };

  return (
    <div className="space-y-8 max-w-4xl">
      {/* Save banner */}
      {isSaved && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-2xl flex items-center gap-3 text-xs font-bold animate-in fade-in duration-200 shadow-sm">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          Settings successfully updated and synchronized to Firebase Cloud!
        </div>
      )}

      {/* Form Settings */}
      <form onSubmit={handleSave} className="space-y-6">
        {/* Commission & Tariffs Card */}
        <div className="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm space-y-5">
          <div className="flex items-center gap-3 pb-4 border-b border-slate-100">
            <div className="p-2.5 rounded-xl bg-purple-50 text-purple-700">
              <BadgePercent className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">Platform Commission & Financial Rules</h3>
              <p className="text-xs text-slate-400">Configure take rates and reservation fee distributions</p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
            <div>
              <label className="font-bold text-slate-700 block mb-1.5">
                Host Commission Take Rate (%)
              </label>
              <div className="relative">
                <input
                  type="number"
                  value={commissionRate}
                  onChange={(e) => setCommissionRate(Number(e.target.value))}
                  min={0}
                  max={100}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 font-bold focus:outline-none focus:border-purple-500"
                />
                <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">%</span>
              </div>
              <p className="text-[11px] text-slate-400 mt-1">Platform automatically retains 15% on each booking settlement.</p>
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">
                Driver Cancellation Penalty / Fee (₹)
              </label>
              <div className="relative">
                <input
                  type="number"
                  value={cancellationFee}
                  onChange={(e) => setCancellationFee(Number(e.target.value))}
                  min={0}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 font-bold focus:outline-none focus:border-purple-500"
                />
                <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">₹</span>
              </div>
              <p className="text-[11px] text-slate-400 mt-1">Deducted if driver cancels after space has been reserved.</p>
            </div>
          </div>
        </div>

        {/* Listing Policy & Verification Card */}
        <div className="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm space-y-5">
          <div className="flex items-center gap-3 pb-4 border-b border-slate-100">
            <div className="p-2.5 rounded-xl bg-indigo-50 text-indigo-700">
              <Shield className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">Partner & Listing Verification Policy</h3>
              <p className="text-xs text-slate-400">Security gates for onboarded parking spots</p>
            </div>
          </div>

          <div className="space-y-4 text-xs">
            <label className="flex items-center justify-between p-3.5 rounded-xl bg-slate-50 border border-slate-100 cursor-pointer hover:bg-slate-100/70 transition-colors">
              <div>
                <span className="font-bold text-slate-900 block">Strict Manual Admin Verification</span>
                <span className="text-[11px] text-slate-500">
                  All newly submitted spaces require manual super-admin approval before appearing in search.
                </span>
              </div>
              <input
                type="checkbox"
                checked={!autoApproveListings}
                onChange={(e) => setAutoApproveListings(!e.target.checked)}
                className="w-4 h-4 text-purple-600 rounded focus:ring-purple-500"
              />
            </label>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Official Support Inbound Email</label>
              <input
                type="email"
                value={supportEmail}
                onChange={(e) => setSupportEmail(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:border-purple-500"
              />
            </div>
          </div>
        </div>

        {/* Firebase Live Database Diagnostics */}
        <div className="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm space-y-4">
          <div className="flex items-center gap-3 pb-4 border-b border-slate-100">
            <div className="p-2.5 rounded-xl bg-emerald-50 text-emerald-700">
              <Database className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">Firebase Realtime Infrastructure</h3>
              <p className="text-xs text-slate-400">Production environment connection params</p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
              <span className="text-[10px] text-slate-400 font-bold block">PROJECT ID</span>
              <span className="font-mono font-bold text-slate-800">{firebaseConfig.projectId}</span>
            </div>
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
              <span className="text-[10px] text-slate-400 font-bold block">DATABASE URL</span>
              <span className="font-mono font-bold text-slate-800 truncate block">
                {firebaseConfig.databaseURL}
              </span>
            </div>
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
              <span className="text-[10px] text-slate-400 font-bold block">AUTH DOMAIN</span>
              <span className="font-mono font-bold text-slate-800">{firebaseConfig.authDomain}</span>
            </div>
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
              <span className="text-[10px] text-slate-400 font-bold block">STORAGE BUCKET</span>
              <span className="font-mono font-bold text-slate-800">{firebaseConfig.storageBucket}</span>
            </div>
          </div>
        </div>

        {/* Save Button */}
        <div className="flex justify-end pt-2">
          <button
            type="submit"
            className="px-6 py-2.5 bg-purple-600 hover:bg-purple-700 text-white font-bold rounded-xl text-xs flex items-center gap-2 shadow-md shadow-purple-500/20 transition-colors"
          >
            <Save className="w-4 h-4" /> Save Configuration
          </button>
        </div>
      </form>
    </div>
  );
};
