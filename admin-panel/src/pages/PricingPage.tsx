import React, { useEffect, useState } from 'react';
import {
  BadgePercent,
  CheckCircle2,
  AlertCircle,
  Save,
  Clock,
  Calendar,
  Sparkles,
  Layers,
  Bike,
  Car,
  Building2,
  Check,
  X,
  ExternalLink,
  MapPin,
  Camera,
  RefreshCw,
} from 'lucide-react';
import { FirebaseAdminService } from '../services/firebaseService';
import { AdminBasePricing, PartnerApprovalRequest, VehicleRateMatrix } from '../types';
import { Modal } from '../components/common/Modal';

export const PricingPage: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'pricing' | 'requests'>('pricing');
  const [pricing, setPricing] = useState<AdminBasePricing>({
    twoWheeler: { hourly: 30, daily: 150, weekly: 750, monthly: 2250 },
    threeWheeler: { hourly: 45, daily: 225, weekly: 1125, monthly: 3375 },
    fourWheeler: { hourly: 60, daily: 300, weekly: 1500, monthly: 4500 },
  });
  const [partnerRequests, setPartnerRequests] = useState<PartnerApprovalRequest[]>([]);
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [selectedRequest, setSelectedRequest] = useState<PartnerApprovalRequest | null>(null);
  const [rejectModalReq, setRejectModalReq] = useState<PartnerApprovalRequest | null>(null);
  const [rejectReason, setRejectReason] = useState('Pricing deviates from platform policy / Inadequate photo verification');
  const [isProcessingApproval, setIsProcessingApproval] = useState(false);

  useEffect(() => {
    const unsubPricing = FirebaseAdminService.subscribeBasePricing(setPricing);
    const unsubRequests = FirebaseAdminService.subscribePartnerRequests(setPartnerRequests);
    return () => {
      unsubPricing();
      unsubRequests();
    };
  }, []);

  const handlePriceChange = (
    category: 'twoWheeler' | 'threeWheeler' | 'fourWheeler',
    field: keyof VehicleRateMatrix,
    value: number
  ) => {
    setPricing((prev) => ({
      ...prev,
      [category]: {
        ...prev[category],
        [field]: Math.max(0, value),
      },
    }));
  };

  const handleSavePricing = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    try {
      await FirebaseAdminService.saveBasePricing(pricing);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3500);
    } catch (err) {
      console.error('Failed to save pricing:', err);
      alert('Failed to save pricing configuration. Check console.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleApproveRequest = async (spaceId: string) => {
    setIsProcessingApproval(true);
    try {
      await FirebaseAdminService.approvePartnerRequest(spaceId);
      if (selectedRequest?.spaceId === spaceId) {
        setSelectedRequest(null);
      }
    } catch (err) {
      console.error('Approval failed:', err);
    } finally {
      setIsProcessingApproval(false);
    }
  };

  const handleExecuteReject = async () => {
    if (!rejectModalReq) return;
    setIsProcessingApproval(true);
    try {
      await FirebaseAdminService.rejectPartnerRequest(rejectModalReq.spaceId, rejectReason);
      setRejectModalReq(null);
      if (selectedRequest?.spaceId === rejectModalReq.spaceId) {
        setSelectedRequest(null);
      }
    } catch (err) {
      console.error('Rejection failed:', err);
    } finally {
      setIsProcessingApproval(false);
    }
  };

  const pendingRequests = partnerRequests.filter((r) => r.status === 'pending_approval');

  return (
    <div className="space-y-6 max-w-6xl">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-purple-900 via-indigo-900 to-slate-900 rounded-2xl p-6 text-white shadow-lg flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="space-y-1.5">
          <div className="flex items-center gap-2">
            <span className="bg-purple-500/20 text-purple-200 border border-purple-400/30 text-[10px] font-extrabold uppercase px-2.5 py-0.5 rounded-full">
              💰 Dynamic Tariffs & Onboarding Control
            </span>
            <h2 className="font-extrabold text-xl text-white">Platform Base Pricing & Space Review</h2>
          </div>
          <p className="text-xs text-purple-200/90 max-w-3xl leading-relaxed">
            Configure the baseline default pricing prefilled into partner onboarding wizard and space creation. Review new partner listing requests and manage approval lifecycles in real time.
          </p>
        </div>

        {/* Tab switcher pill */}
        <div className="flex items-center bg-white/10 backdrop-blur-md p-1 rounded-xl border border-white/15 w-full sm:w-auto justify-between sm:justify-start shrink-0">
          <button
            onClick={() => setActiveTab('pricing')}
            className={`flex-1 sm:flex-none px-3 sm:px-4 py-2 rounded-lg text-xs font-bold transition-all text-center ${
              activeTab === 'pricing'
                ? 'bg-white text-purple-900 shadow-md'
                : 'text-purple-200 hover:text-white'
            }`}
          >
            Base Pricing Matrix
          </button>
          <button
            onClick={() => setActiveTab('requests')}
            className={`flex-1 sm:flex-none px-3 sm:px-4 py-2 rounded-lg text-xs font-bold transition-all relative flex items-center justify-center gap-1.5 text-center ${
              activeTab === 'requests'
                ? 'bg-white text-purple-900 shadow-md'
                : 'text-purple-200 hover:text-white'
            }`}
          >
            <span>Partner Requests</span>
            {pendingRequests.length > 0 && (
              <span className="bg-amber-400 text-slate-900 font-extrabold text-[10px] px-1.5 py-0.2 rounded-full">
                {pendingRequests.length}
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Success Notification */}
      {saveSuccess && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-2xl flex items-center justify-between gap-3 text-xs font-bold shadow-sm animate-in fade-in duration-200">
          <div className="flex items-center gap-2.5">
            <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
            <span>Base Pricing successfully saved and synchronized with the mobile app RTDB (`adminConfig/basePricing`)!</span>
          </div>
          <span className="text-[11px] text-emerald-600 font-normal">Active globally</span>
        </div>
      )}

      {/* TAB 1: BASE PRICING MATRIX */}
      {activeTab === 'pricing' && (
        <form onSubmit={handleSavePricing} className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* 🚲 2-Wheeler Card */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
              <div className="bg-emerald-50/80 p-4 border-b border-emerald-100 flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 bg-emerald-500 text-white rounded-xl shadow-sm">
                    <Bike className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-slate-900">2-Wheeler Rates</h3>
                    <p className="text-[11px] text-emerald-700 font-medium">Bikes, Scooters & EV 2W</p>
                  </div>
                </div>
                <span className="text-xs font-extrabold text-emerald-700 bg-white px-2 py-0.5 rounded-lg border border-emerald-200">
                  Base Tier
                </span>
              </div>

              <div className="p-5 space-y-4 flex-1 text-xs">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Hourly Base Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.twoWheeler.hourly}
                      onChange={(e) => handlePriceChange('twoWheeler', 'hourly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/hr</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Daily Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.twoWheeler.daily}
                      onChange={(e) => handlePriceChange('twoWheeler', 'daily', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/day</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Weekly Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.twoWheeler.weekly}
                      onChange={(e) => handlePriceChange('twoWheeler', 'weekly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/wk</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Monthly Pass (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.twoWheeler.monthly}
                      onChange={(e) => handlePriceChange('twoWheeler', 'monthly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/mo</span>
                  </div>
                </div>
              </div>
            </div>

            {/* 🛺 3-Wheeler Card */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
              <div className="bg-amber-50/80 p-4 border-b border-amber-100 flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 bg-amber-500 text-white rounded-xl shadow-sm">
                    <Layers className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-slate-900">3-Wheeler Rates</h3>
                    <p className="text-[11px] text-amber-700 font-medium">Auto-Rickshaws & E-Rickshaws</p>
                  </div>
                </div>
                <span className="text-xs font-extrabold text-amber-700 bg-white px-2 py-0.5 rounded-lg border border-amber-200">
                  Mid Tier
                </span>
              </div>

              <div className="p-5 space-y-4 flex-1 text-xs">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Hourly Base Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.threeWheeler.hourly}
                      onChange={(e) => handlePriceChange('threeWheeler', 'hourly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/hr</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Daily Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.threeWheeler.daily}
                      onChange={(e) => handlePriceChange('threeWheeler', 'daily', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/day</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Weekly Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.threeWheeler.weekly}
                      onChange={(e) => handlePriceChange('threeWheeler', 'weekly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/wk</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Monthly Pass (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.threeWheeler.monthly}
                      onChange={(e) => handlePriceChange('threeWheeler', 'monthly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/mo</span>
                  </div>
                </div>
              </div>
            </div>

            {/* 🚗 4-Wheeler Card */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
              <div className="bg-indigo-50/80 p-4 border-b border-indigo-100 flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 bg-indigo-600 text-white rounded-xl shadow-sm">
                    <Car className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-slate-900">4-Wheeler Rates</h3>
                    <p className="text-[11px] text-indigo-700 font-medium">Hatchbacks, Sedans & SUVs</p>
                  </div>
                </div>
                <span className="text-xs font-extrabold text-indigo-700 bg-white px-2 py-0.5 rounded-lg border border-indigo-200">
                  Prime Tier
                </span>
              </div>

              <div className="p-5 space-y-4 flex-1 text-xs">
                <div>
                  <label className="font-bold text-slate-700 block mb-1">Hourly Base Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.fourWheeler.hourly}
                      onChange={(e) => handlePriceChange('fourWheeler', 'hourly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/hr</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Daily Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.fourWheeler.daily}
                      onChange={(e) => handlePriceChange('fourWheeler', 'daily', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/day</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Weekly Rate (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.fourWheeler.weekly}
                      onChange={(e) => handlePriceChange('fourWheeler', 'weekly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/wk</span>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-slate-700 block mb-1">Monthly Pass (₹)</label>
                  <div className="relative">
                    <input
                      type="number"
                      value={pricing.fourWheeler.monthly}
                      onChange={(e) => handlePriceChange('fourWheeler', 'monthly', Number(e.target.value))}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 font-bold text-slate-900 focus:outline-none focus:border-purple-500"
                    />
                    <span className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold">/mo</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Action Row */}
          <div className="flex flex-col sm:flex-row items-center justify-between p-5 bg-slate-50 border border-slate-200 rounded-2xl gap-4">
            <div className="flex items-center gap-2 text-xs text-slate-500 font-medium">
              <Clock className="w-4 h-4 text-purple-600" />
              <span>
                Last Updated:{' '}
                {pricing.updatedAt ? new Date(pricing.updatedAt).toLocaleString() : 'System Default'}
              </span>
            </div>

            <button
              type="submit"
              disabled={isSaving}
              className="px-6 py-3 bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white font-bold rounded-xl text-xs flex items-center gap-2 shadow-md shadow-purple-500/20 transition-all cursor-pointer"
            >
              {isSaving ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" /> Saving Rates...
                </>
              ) : (
                <>
                  <Save className="w-4 h-4" /> Save Base Pricing to RTDB
                </>
              )}
            </button>
          </div>
        </form>
      )}

      {/* TAB 2: PARTNER LISTING APPROVAL REQUESTS */}
      {activeTab === 'requests' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-extrabold text-slate-800">
              New Partner Parking Submissions ({partnerRequests.length})
            </h3>
            <span className="text-xs text-slate-400">
              {pendingRequests.length} pending review
            </span>
          </div>

          {partnerRequests.length === 0 ? (
            <div className="bg-white p-12 rounded-2xl border border-slate-200 text-center space-y-3">
              <Building2 className="w-12 h-12 text-slate-300 mx-auto" />
              <h4 className="text-sm font-bold text-slate-800">No Partner Requests Yet</h4>
              <p className="text-xs text-slate-400 max-w-sm mx-auto">
                When partners complete onboarding and submit new parking spaces in the app, their requests will appear here for admin approval.
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {partnerRequests.map((req) => {
                const isPending = req.status === 'pending_approval';
                const isApproved = req.status === 'approved';

                return (
                  <div
                    key={req.spaceId}
                    className={`bg-white rounded-2xl border p-5 shadow-sm space-y-4 transition-all ${
                      isPending ? 'border-amber-200/90 ring-1 ring-amber-100' : 'border-slate-200'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <span
                            className={`text-[10px] font-extrabold px-2 py-0.5 rounded-md uppercase ${
                              isPending
                                ? 'bg-amber-100 text-amber-800'
                                : isApproved
                                ? 'bg-emerald-100 text-emerald-800'
                                : 'bg-rose-100 text-rose-800'
                            }`}
                          >
                            {isPending ? 'Pending Approval' : req.status}
                          </span>
                          <span className="text-[11px] text-slate-400">
                            {new Date(req.submittedAt).toLocaleDateString()}
                          </span>
                        </div>
                        <h4 className="text-base font-bold text-slate-900 leading-snug">
                          {req.spaceTitle}
                        </h4>
                        <p className="text-xs text-slate-500 flex items-center gap-1">
                          <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                          <span className="truncate">{req.address || req.city || 'Address not specified'}</span>
                        </p>
                      </div>

                      <div className="p-2.5 rounded-xl bg-purple-50 text-purple-700 shrink-0">
                        <Building2 className="w-5 h-5" />
                      </div>
                    </div>

                    {/* Partner Details Box */}
                    <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 text-xs grid grid-cols-2 gap-2">
                      <div>
                        <span className="text-[10px] font-bold text-slate-400 uppercase block">Host Name</span>
                        <span className="font-bold text-slate-800">{req.partnerName || 'Registered Partner'}</span>
                      </div>
                      <div>
                        <span className="text-[10px] font-bold text-slate-400 uppercase block">Contact Phone</span>
                        <span className="font-bold text-slate-800">{req.partnerPhone || 'N/A'}</span>
                      </div>
                      <div>
                        <span className="text-[10px] font-bold text-slate-400 uppercase block">Land Area</span>
                        <span className="font-semibold text-slate-700">{req.totalLandSqMeters || 150} sq.m</span>
                      </div>
                      <div>
                        <span className="text-[10px] font-bold text-slate-400 uppercase block">Capacity</span>
                        <span className="font-semibold text-slate-700">
                          {req.maxCars || 0} Cars • {req.maxBikes || 0} Bikes
                        </span>
                      </div>
                    </div>

                    {/* Photo Thumbnails Preview */}
                    {req.images && req.images.length > 0 && (
                      <div className="space-y-1.5">
                        <div className="flex items-center justify-between text-[11px] text-slate-500 font-semibold">
                          <span className="flex items-center gap-1">
                            <Camera className="w-3.5 h-3.5" /> Uploaded Photos ({req.images.length})
                          </span>
                        </div>
                        <div className="flex gap-2 overflow-x-auto pb-1">
                          {req.images.map((imgUrl, i) => (
                            <img
                              key={i}
                              src={imgUrl}
                              alt="Spot"
                              className="w-16 h-14 rounded-lg object-cover border border-slate-200 shrink-0"
                            />
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Action Buttons */}
                    {isPending ? (
                      <div className="flex items-center gap-2 pt-2 border-t border-slate-100">
                        <button
                          onClick={() => handleApproveRequest(req.spaceId)}
                          disabled={isProcessingApproval}
                          className="flex-1 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 shadow-sm transition-colors cursor-pointer"
                        >
                          <Check className="w-3.5 h-3.5" /> Approve & Publish Live
                        </button>
                        <button
                          onClick={() => setRejectModalReq(req)}
                          disabled={isProcessingApproval}
                          className="py-2 px-3 bg-rose-50 hover:bg-rose-100 text-rose-700 font-bold rounded-xl text-xs flex items-center justify-center gap-1 border border-rose-200 transition-colors cursor-pointer"
                        >
                          <X className="w-3.5 h-3.5" /> Reject
                        </button>
                      </div>
                    ) : (
                      <div className="text-[11px] text-slate-400 font-medium pt-1">
                        {isApproved ? '✅ Verified and active on public map' : `❌ Rejected: ${req.rejectionReason || 'Policy non-compliance'}`}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* Reject Modal */}
      {rejectModalReq && (
        <Modal
          isOpen={true}
          onClose={() => setRejectModalReq(null)}
          title="Reject Parking Space Submission"
        >
          <div className="space-y-4 text-xs">
            <p className="text-slate-600">
              Please specify the reason for rejecting <strong>{rejectModalReq.spaceTitle}</strong> submitted by {rejectModalReq.partnerName}:
            </p>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">Rejection Reason</label>
              <textarea
                rows={3}
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:border-rose-500"
              />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => setRejectModalReq(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 font-bold rounded-xl text-slate-700"
              >
                Cancel
              </button>
              <button
                onClick={handleExecuteReject}
                disabled={isProcessingApproval}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-700 font-bold text-white rounded-xl"
              >
                Confirm Rejection
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
