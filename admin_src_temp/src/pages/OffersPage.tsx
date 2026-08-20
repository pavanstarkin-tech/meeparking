import React, { useEffect, useState } from 'react';
import {
  Tag,
  Plus,
  Search,
  Sparkles,
  Percent,
  Coins,
  Calendar,
  CheckCircle2,
  XCircle,
  Edit2,
  Trash2,
  Copy,
  Check,
  Zap,
  Clock,
  Layers,
  ArrowRight,
  Gift,
} from 'lucide-react';
import { FirebaseAdminService } from '../services/firebaseService';
import { Offer } from '../types';
import { Modal } from '../components/common/Modal';

export const OffersPage: React.FC = () => {
  const [offers, setOffers] = useState<Offer[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCategory, setFilterCategory] = useState<string>('all');
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingOffer, setEditingOffer] = useState<Offer | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [deleteModalOffer, setDeleteModalOffer] = useState<Offer | null>(null);

  // Form State
  const [formData, setFormData] = useState<Partial<Offer>>({
    code: '',
    title: '',
    description: '',
    discountType: 'percentage',
    discountValue: 20,
    maxDiscount: 100,
    minBookingAmount: 50,
    category: 'all',
    isActive: true,
    color: '#7C3AED',
    validTill: '',
  });

  useEffect(() => {
    const unsub = FirebaseAdminService.subscribeOffers((data) => {
      setOffers(data);
    });
    return () => unsub();
  }, []);

  const handleCopy = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(code);
    setTimeout(() => setCopiedCode(null), 2000);
  };

  const handleOpenCreateModal = () => {
    setEditingOffer(null);
    setFormData({
      code: '',
      title: '',
      description: '',
      discountType: 'percentage',
      discountValue: 20,
      maxDiscount: 100,
      minBookingAmount: 50,
      category: 'all',
      isActive: true,
      color: '#7C3AED',
      validTill: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    });
    setIsModalOpen(true);
  };

  const handleOpenEditModal = (offer: Offer) => {
    setEditingOffer(offer);
    setFormData({ ...offer });
    setIsModalOpen(true);
  };

  const handleSaveOffer = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.code || !formData.title) {
      alert('Please fill in required fields (Coupon Code & Title)');
      return;
    }

    setIsSubmitting(true);
    try {
      const payload: Offer = {
        id: editingOffer?.id || formData.code.trim().toUpperCase(),
        code: formData.code.trim().toUpperCase(),
        title: formData.title.trim(),
        description: formData.description?.trim() || '',
        discountType: formData.discountType || 'percentage',
        discountValue: Number(formData.discountValue) || 0,
        maxDiscount: formData.maxDiscount ? Number(formData.maxDiscount) : undefined,
        minBookingAmount: formData.minBookingAmount ? Number(formData.minBookingAmount) : 0,
        category: (formData.category as any) || 'all',
        isActive: formData.isActive !== false,
        color: formData.color || '#7C3AED',
        validTill: formData.validTill || undefined,
        createdAt: editingOffer?.createdAt || new Date().toISOString(),
      };

      await FirebaseAdminService.createOrUpdateOffer(payload);
      setIsModalOpen(false);
    } catch (err) {
      console.error('Failed to save offer:', err);
      alert('Failed to save offer. Check console.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleActive = async (offer: Offer) => {
    try {
      await FirebaseAdminService.toggleOfferStatus(offer.id, !offer.isActive);
    } catch (err) {
      console.error('Failed to toggle status:', err);
    }
  };

  const handleDelete = async () => {
    if (!deleteModalOffer) return;
    try {
      await FirebaseAdminService.deleteOffer(deleteModalOffer.id);
      setDeleteModalOffer(null);
    } catch (err) {
      console.error('Failed to delete offer:', err);
    }
  };

  const filteredOffers = offers.filter((o) => {
    const q = searchQuery.toLowerCase();
    const matchesQuery =
      o.code.toLowerCase().includes(q) ||
      o.title.toLowerCase().includes(q) ||
      o.description.toLowerCase().includes(q);
    const matchesCategory = filterCategory === 'all' || o.category === filterCategory;
    return matchesQuery && matchesCategory;
  });

  const activeCount = offers.filter((o) => o.isActive).length;
  const percentageCount = offers.filter((o) => o.discountType === 'percentage').length;
  const flatCount = offers.filter((o) => o.discountType === 'flat').length;

  return (
    <div className="space-y-6">
      {/* 1. Header & Quick Action */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2.5">
            <Tag className="w-7 h-7 text-purple-600" />
            Offers & Promo Codes
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Create and manage promotional discounts streaming in real-time to user booking checkout.
          </p>
        </div>

        <button
          onClick={handleOpenCreateModal}
          className="inline-flex items-center justify-center gap-2 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-700 hover:to-indigo-700 text-white font-bold px-5 py-2.5 rounded-xl shadow-lg shadow-purple-500/25 transition-all text-sm"
        >
          <Plus className="w-4 h-4" />
          Create New Offer
        </button>
      </div>

      {/* 2. Metric Overview Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white border border-slate-200/80 rounded-2xl p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Active Promos</span>
            <div className="p-2 bg-purple-50 rounded-xl">
              <Sparkles className="w-4 h-4 text-purple-600" />
            </div>
          </div>
          <p className="text-2xl font-black text-slate-900 mt-2">{activeCount} / {offers.length}</p>
          <p className="text-xs text-purple-600 font-semibold mt-1">Live on Seeker app</p>
        </div>

        <div className="bg-white border border-slate-200/80 rounded-2xl p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Percentage (%) Deals</span>
            <div className="p-2 bg-blue-50 rounded-xl">
              <Percent className="w-4 h-4 text-blue-600" />
            </div>
          </div>
          <p className="text-2xl font-black text-slate-900 mt-2">{percentageCount}</p>
          <p className="text-xs text-slate-500 mt-1">Relative value discounts</p>
        </div>

        <div className="bg-white border border-slate-200/80 rounded-2xl p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Flat (₹) Off</span>
            <div className="p-2 bg-emerald-50 rounded-xl">
              <Coins className="w-4 h-4 text-emerald-600" />
            </div>
          </div>
          <p className="text-2xl font-black text-slate-900 mt-2">{flatCount}</p>
          <p className="text-xs text-slate-500 mt-1">Direct wallet reductions</p>
        </div>

        <div className="bg-white border border-slate-200/80 rounded-2xl p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Total Campaigns</span>
            <div className="p-2 bg-amber-50 rounded-xl">
              <Gift className="w-4 h-4 text-amber-600" />
            </div>
          </div>
          <p className="text-2xl font-black text-slate-900 mt-2">{offers.length}</p>
          <p className="text-xs text-slate-500 mt-1">In Realtime DB</p>
        </div>
      </div>

      {/* 3. Search & Filter Bar */}
      <div className="bg-white border border-slate-200/80 rounded-2xl p-4 shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search code, title or terms..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-600 transition-all font-medium text-slate-900"
          />
        </div>

        <div className="flex items-center gap-2 overflow-x-auto w-full sm:w-auto pb-1 sm:pb-0">
          {[
            { key: 'all', label: 'All Categories' },
            { key: 'first_booking', label: 'First Booking' },
            { key: 'weekend', label: 'Weekend' },
            { key: 'ev', label: 'EV Charging' },
          ].map((tab) => (
            <button
              key={tab.key}
              onClick={() => setFilterCategory(tab.key)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
                filterCategory === tab.key
                  ? 'bg-purple-600 text-white shadow-sm'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200/70'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* 4. Offers Grid */}
      {filteredOffers.length === 0 ? (
        <div className="bg-white border border-slate-200/80 rounded-2xl p-12 text-center shadow-sm">
          <div className="w-14 h-14 bg-purple-50 text-purple-600 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <Tag className="w-7 h-7" />
          </div>
          <h3 className="text-lg font-bold text-slate-900">No Offers Found</h3>
          <p className="text-sm text-slate-500 mt-1 max-w-md mx-auto">
            {searchQuery ? 'No coupons matched your search criteria.' : 'Create your first promotional discount offer for drivers.'}
          </p>
          <button
            onClick={handleOpenCreateModal}
            className="mt-5 inline-flex items-center gap-2 bg-purple-600 text-white text-xs font-bold px-4 py-2.5 rounded-xl hover:bg-purple-700 transition"
          >
            <Plus className="w-4 h-4" /> Create Offer Now
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredOffers.map((offer) => {
            const isCopied = copiedCode === offer.code;
            return (
              <div
                key={offer.id}
                className={`bg-white rounded-2xl border transition-all duration-200 flex flex-col justify-between overflow-hidden shadow-sm hover:shadow-md ${
                  offer.isActive ? 'border-slate-200/80' : 'border-slate-200 opacity-60'
                }`}
              >
                {/* Colored Top Brand Ribbon */}
                <div
                  className="p-4 text-white relative overflow-hidden"
                  style={{
                    background: `linear-gradient(135deg, ${offer.color || '#7C3AED'}, ${offer.color ? offer.color + 'dd' : '#5B21B6'})`,
                  }}
                >
                  <div className="flex items-start justify-between gap-2 relative z-10">
                    <div>
                      <span className="inline-block bg-white/20 backdrop-blur-md text-white text-[10px] font-extrabold uppercase px-2.5 py-0.5 rounded-full border border-white/30 mb-1.5">
                        {offer.category === 'first_booking'
                          ? 'New Users'
                          : offer.category === 'weekend'
                          ? 'Weekend Special'
                          : offer.category === 'ev'
                          ? 'EV Exclusive'
                          : 'Platform Promo'}
                      </span>
                      <h4 className="font-extrabold text-base tracking-tight text-white leading-tight">
                        {offer.title}
                      </h4>
                    </div>

                    {/* Copy Code Pill */}
                    <button
                      onClick={() => handleCopy(offer.code)}
                      className="shrink-0 bg-white text-slate-900 px-3 py-1.5 rounded-xl font-mono text-xs font-black flex items-center gap-1.5 shadow-sm hover:bg-purple-50 transition border border-white/50"
                      title="Copy promo code"
                    >
                      <span>{offer.code}</span>
                      {isCopied ? (
                        <Check className="w-3.5 h-3.5 text-emerald-600" />
                      ) : (
                        <Copy className="w-3.5 h-3.5 text-slate-400" />
                      )}
                    </button>
                  </div>

                  <p className="text-white/80 text-xs mt-2.5 leading-relaxed relative z-10">
                    {offer.description}
                  </p>
                </div>

                {/* Offer Details Body */}
                <div className="p-4 space-y-3 flex-1 flex flex-col justify-between">
                  <div className="grid grid-cols-2 gap-2 text-xs bg-slate-50 p-2.5 rounded-xl border border-slate-100">
                    <div>
                      <span className="text-slate-400 block text-[10px] uppercase font-bold">Discount</span>
                      <span className="font-extrabold text-slate-800 text-sm">
                        {offer.discountType === 'percentage' ? `${offer.discountValue}% OFF` : `₹${offer.discountValue} FLAT`}
                      </span>
                      {offer.maxDiscount && (
                        <span className="text-[10px] text-slate-400 block">Up to ₹{offer.maxDiscount}</span>
                      )}
                    </div>
                    <div>
                      <span className="text-slate-400 block text-[10px] uppercase font-bold">Min Spend</span>
                      <span className="font-extrabold text-slate-800 text-sm">
                        {offer.minBookingAmount ? `₹${offer.minBookingAmount}` : 'No Min'}
                      </span>
                      {offer.validTill && (
                        <span className="text-[10px] text-slate-400 block">Exp: {offer.validTill}</span>
                      )}
                    </div>
                  </div>

                  {/* Actions Footer */}
                  <div className="flex items-center justify-between pt-2 border-t border-slate-100">
                    <button
                      onClick={() => handleToggleActive(offer)}
                      className={`inline-flex items-center gap-1.5 text-xs font-bold px-2.5 py-1 rounded-lg transition ${
                        offer.isActive
                          ? 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                          : 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                      }`}
                    >
                      {offer.isActive ? (
                        <>
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" /> Active
                        </>
                      ) : (
                        <>
                          <XCircle className="w-3.5 h-3.5 text-slate-400" /> Inactive
                        </>
                      )}
                    </button>

                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => handleOpenEditModal(offer)}
                        className="p-1.5 text-slate-400 hover:text-purple-600 hover:bg-purple-50 rounded-lg transition"
                        title="Edit Offer"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setDeleteModalOffer(offer)}
                        className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                        title="Delete Offer"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* 5. Create / Edit Offer Modal */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title={editingOffer ? 'Edit Promotional Offer' : 'Create New Promotional Offer'}
        maxWidth="max-w-xl"
      >
        <form onSubmit={handleSaveOffer} className="space-y-4">
          {/* Coupon Live Preview Card */}
          <div>
            <label className="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">
              Live Card Preview
            </label>
            <div
              className="p-4 rounded-2xl text-white shadow-md relative overflow-hidden transition-all"
              style={{
                background: `linear-gradient(135deg, ${formData.color || '#7C3AED'}, ${
                  formData.color ? formData.color + 'cc' : '#5B21B6'
                })`,
              }}
            >
              <div className="flex items-start justify-between gap-2">
                <div>
                  <span className="inline-block bg-white/20 text-white text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-full mb-1">
                    {formData.category || 'all'}
                  </span>
                  <h4 className="font-black text-base text-white">
                    {formData.title || 'Offer Title Preview'}
                  </h4>
                </div>
                <span className="bg-white text-slate-900 px-2.5 py-1 rounded-lg font-mono text-xs font-black">
                  {formData.code || 'PROMOCODE'}
                </span>
              </div>
              <p className="text-white/80 text-xs mt-1.5">
                {formData.description || 'Terms & discount description will appear here.'}
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Coupon Code *</label>
              <input
                type="text"
                required
                placeholder="e.g. MEEPARK50"
                value={formData.code || ''}
                onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                className="w-full px-3 py-2 text-sm uppercase font-mono font-bold bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-purple-500/20 focus:border-purple-600 focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Category Target</label>
              <select
                value={formData.category || 'all'}
                onChange={(e) => setFormData({ ...formData, category: e.target.value as any })}
                className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-purple-500/20 focus:border-purple-600 focus:outline-none font-semibold text-slate-800"
              >
                <option value="all">All Parking Bookings</option>
                <option value="first_booking">First Booking (New Users)</option>
                <option value="weekend">Weekend Special</option>
                <option value="ev">EV Charging Spaces</option>
              </select>
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">Offer Display Title *</label>
            <input
              type="text"
              required
              placeholder="e.g. 50% OFF Weekend Parking"
              value={formData.title || ''}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              className="w-full px-3 py-2 text-sm font-semibold bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-purple-500/20 focus:border-purple-600 focus:outline-none"
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">Description / Subtitle</label>
            <textarea
              rows={2}
              placeholder="e.g. Get 50% discount up to ₹100 on your first parking reservation."
              value={formData.description || ''}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-purple-500/20 focus:border-purple-600 focus:outline-none"
            />
          </div>

          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Type</label>
              <select
                value={formData.discountType || 'percentage'}
                onChange={(e) => setFormData({ ...formData, discountType: e.target.value as any })}
                className="w-full px-2.5 py-2 text-xs font-bold bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
              >
                <option value="percentage">Percentage (%)</option>
                <option value="flat">Flat (₹)</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Value *</label>
              <input
                type="number"
                required
                min={1}
                value={formData.discountValue || ''}
                onChange={(e) => setFormData({ ...formData, discountValue: Number(e.target.value) })}
                className="w-full px-3 py-2 text-sm font-bold bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Max Cap (₹)</label>
              <input
                type="number"
                placeholder="Optional"
                value={formData.maxDiscount || ''}
                onChange={(e) => setFormData({ ...formData, maxDiscount: e.target.value ? Number(e.target.value) : undefined })}
                className="w-full px-3 py-2 text-sm font-bold bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Min Booking Spend (₹)</label>
              <input
                type="number"
                min={0}
                value={formData.minBookingAmount || 0}
                onChange={(e) => setFormData({ ...formData, minBookingAmount: Number(e.target.value) })}
                className="w-full px-3 py-2 text-sm font-bold bg-slate-50 border border-slate-200 rounded-xl focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Theme Accent Color</label>
              <div className="flex items-center gap-2">
                <input
                  type="color"
                  value={formData.color || '#7C3AED'}
                  onChange={(e) => setFormData({ ...formData, color: e.target.value })}
                  className="w-9 h-9 p-0.5 rounded-lg border border-slate-200 cursor-pointer"
                />
                <span className="text-xs font-mono text-slate-500 uppercase">{formData.color || '#7C3AED'}</span>
              </div>
            </div>
          </div>

          <div className="flex items-center justify-between pt-2">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={formData.isActive !== false}
                onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                className="w-4 h-4 text-purple-600 rounded focus:ring-purple-500"
              />
              <span className="text-xs font-bold text-slate-700">Publish as Active immediately</span>
            </label>
          </div>

          <div className="flex justify-end gap-3 pt-3 border-t border-slate-100">
            <button
              type="button"
              onClick={() => setIsModalOpen(false)}
              className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-5 py-2 text-xs font-bold bg-purple-600 hover:bg-purple-700 text-white rounded-xl shadow-md transition disabled:opacity-50"
            >
              {isSubmitting ? 'Saving...' : editingOffer ? 'Update Offer' : 'Publish Offer'}
            </button>
          </div>
        </form>
      </Modal>

      {/* 6. Delete Confirmation Modal */}
      <Modal
        isOpen={!!deleteModalOffer}
        onClose={() => setDeleteModalOffer(null)}
        title="Delete Promotional Offer"
        maxWidth="max-w-md"
      >
        <div className="space-y-4">
          <p className="text-sm text-slate-600">
            Are you sure you want to delete coupon <span className="font-bold font-mono text-slate-900">"{deleteModalOffer?.code}"</span>? Drivers will no longer be able to apply this discount.
          </p>

          <div className="flex justify-end gap-3 pt-2">
            <button
              onClick={() => setDeleteModalOffer(null)}
              className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition"
            >
              Cancel
            </button>
            <button
              onClick={handleDelete}
              className="px-4 py-2 text-xs font-bold bg-rose-600 hover:bg-rose-700 text-white rounded-xl shadow-sm transition"
            >
              Confirm Delete
            </button>
          </div>
        </div>
      </Modal>
    </div>
  );
};
