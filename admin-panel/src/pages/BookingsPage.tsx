import React, { useEffect, useState } from 'react';
import {
  Search,
  Filter,
  Ticket,
  Car,
  Bike,
  Calendar,
  Clock,
  MapPin,
  XCircle,
  Eye,
  AlertTriangle,
  RotateCcw,
  Trash2,
} from 'lucide-react';
import { StatusBadge } from '../components/common/StatusBadge';
import { Modal } from '../components/common/Modal';
import { FirebaseAdminService } from '../services/firebaseService';
import { Booking } from '../types';

export const BookingsPage: React.FC = () => {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [vehicleFilter, setVehicleFilter] = useState<string>('all');
  const [selectedBooking, setSelectedBooking] = useState<Booking | null>(null);
  const [cancelModalBooking, setCancelModalBooking] = useState<Booking | null>(null);
  const [refundAmount, setRefundAmount] = useState<number>(0);
  const [cancelReason, setCancelReason] = useState<string>('Administrative Override');
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    const unsub = FirebaseAdminService.subscribeBookings(setBookings);
    return () => unsub();
  }, []);

  const filteredBookings = bookings.filter((b) => {
    const query = searchQuery.toLowerCase().trim();
    const matchesSearch =
      b.id.toLowerCase().includes(query) ||
      b.vehicleNumber.toLowerCase().includes(query) ||
      b.spaceTitle.toLowerCase().includes(query) ||
      b.spaceAddress.toLowerCase().includes(query) ||
      b.userId.toLowerCase().includes(query);

    const matchesStatus =
      statusFilter === 'all' || b.status.toLowerCase() === statusFilter.toLowerCase();

    const matchesVehicle =
      vehicleFilter === 'all' ||
      (vehicleFilter === 'bike' && (b.vehicleType.toLowerCase().includes('2') || b.vehicleType.toLowerCase().includes('bike'))) ||
      (vehicleFilter === 'car' && (b.vehicleType.toLowerCase().includes('4') || b.vehicleType.toLowerCase().includes('car')));

    return matchesSearch && matchesStatus && matchesVehicle;
  });

  const handleOpenCancelModal = (booking: Booking) => {
    setCancelModalBooking(booking);
    setRefundAmount(booking.totalAmount);
    setCancelReason('Customer Requested Dispute / Slot Unavailable');
  };

  const handleExecuteCancel = async () => {
    if (!cancelModalBooking) return;
    setIsProcessing(true);
    try {
      await FirebaseAdminService.cancelAndRefundBooking(
        cancelModalBooking,
        refundAmount,
        cancelReason
      );
      setCancelModalBooking(null);
    } catch (e) {
      console.error('Cancellation error:', e);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDeleteBooking = async (bookingId: string) => {
    if (window.confirm('Are you sure you want to permanently delete this booking record?')) {
      await FirebaseAdminService.deleteBooking(bookingId);
    }
  };

  return (
    <div className="space-y-6">
      {/* Filters Bar */}
      <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        {/* Search */}
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by ID, Vehicle, Location..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-10 pr-4 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500 transition-all"
          />
        </div>

        {/* Filters */}
        <div className="flex items-center gap-3 w-full md:w-auto overflow-x-auto pb-1 md:pb-0">
          {/* Status Tabs */}
          <div className="flex items-center bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs font-semibold text-slate-600">
            {['all', 'upcoming', 'completed', 'cancelled'].map((tab) => (
              <button
                key={tab}
                onClick={() => setStatusFilter(tab)}
                className={`px-3 py-1 rounded-lg capitalize transition-all ${
                  statusFilter === tab
                    ? 'bg-white text-purple-700 font-bold shadow-sm'
                    : 'hover:text-slate-900'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>

          {/* Vehicle Dropdown */}
          <select
            value={vehicleFilter}
            onChange={(e) => setVehicleFilter(e.target.value)}
            className="bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 text-xs font-semibold text-slate-700 focus:outline-none focus:border-purple-500"
          >
            <option value="all">All Vehicles</option>
            <option value="car">4-Wheelers (Cars)</option>
            <option value="bike">2-Wheelers (Bikes)</option>
          </select>
        </div>
      </div>

      {/* Bookings Table */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/75 border-b border-slate-100 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                <th className="py-3.5 px-6">Booking Details</th>
                <th className="py-3.5 px-6">Parking Space</th>
                <th className="py-3.5 px-6">Vehicle & Plan</th>
                <th className="py-3.5 px-6">Date & Slot</th>
                <th className="py-3.5 px-6">Amount</th>
                <th className="py-3.5 px-6">Status</th>
                <th className="py-3.5 px-6 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-xs text-slate-700">
              {filteredBookings.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-16 text-center text-slate-400">
                    No reservations matching your filters found.
                  </td>
                </tr>
              ) : (
                filteredBookings.map((booking) => {
                  const isBike =
                    booking.vehicleType.toLowerCase().includes('2') ||
                    booking.vehicleType.toLowerCase().includes('bike');

                  return (
                    <tr key={booking.id} className="hover:bg-slate-50/70 transition-colors">
                      {/* Booking ID & User */}
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div className="p-2.5 rounded-xl bg-purple-50 text-purple-600 font-bold">
                            <Ticket className="w-4 h-4" />
                          </div>
                          <div>
                            <span className="font-extrabold text-slate-900 block">
                              {booking.id.length > 8
                                ? `#${booking.id.substring(booking.id.length - 6).toUpperCase()}`
                                : `#${booking.id}`}
                            </span>
                            <span className="text-[11px] text-slate-400">
                              User: {booking.userId.substring(0, 10)}...
                            </span>
                          </div>
                        </div>
                      </td>

                      {/* Parking Space */}
                      <td className="py-4 px-6 font-medium">
                        <div className="font-bold text-slate-900">{booking.spaceTitle}</div>
                        <div className="text-[11px] text-slate-400 flex items-center gap-1 mt-0.5 max-w-[200px] truncate">
                          <MapPin className="w-3 h-3 text-slate-300 shrink-0" />
                          {booking.spaceAddress}
                        </div>
                      </td>

                      {/* Vehicle & Plan */}
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-1.5 font-bold text-slate-900">
                          {isBike ? (
                            <Bike className="w-3.5 h-3.5 text-emerald-600" />
                          ) : (
                            <Car className="w-3.5 h-3.5 text-purple-600" />
                          )}
                          <span>
                            {booking.vehicleNumber !== 'N/A' && booking.vehicleNumber !== 'DL 01 AB 1234'
                              ? booking.vehicleNumber
                              : (booking.vehicleModel || 'Standard Vehicle')}
                          </span>
                        </div>
                        <div className="text-[11px] text-slate-400 mt-0.5">
                          {booking.vehicleType.toUpperCase()}
                        </div>
                      </td>

                      {/* Date & Slot */}
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-1 font-semibold text-slate-800">
                          <Calendar className="w-3 h-3 text-slate-400" />
                          {booking.bookingDate}
                        </div>
                        <div className="flex items-center gap-1 text-[11px] text-slate-500 mt-0.5">
                          <Clock className="w-3 h-3 text-slate-300" />
                          {booking.timeSlot}
                        </div>
                      </td>

                      {/* Amount */}
                      <td className="py-4 px-6">
                        <span className="font-extrabold text-slate-900 text-sm">
                          ₹{booking.totalAmount}
                        </span>
                        <span className="block text-[10px] text-slate-400">
                          {booking.paymentId || 'Prepaid'}
                        </span>
                      </td>

                      {/* Status */}
                      <td className="py-4 px-6">
                        <StatusBadge status={booking.status} />
                      </td>

                      {/* Action buttons */}
                      <td className="py-4 px-6 text-right space-x-2 whitespace-nowrap">
                        <button
                          onClick={() => setSelectedBooking(booking)}
                          title="View Details"
                          className="p-1.5 text-slate-500 hover:text-purple-700 hover:bg-purple-50 rounded-lg transition-colors"
                        >
                          <Eye className="w-4 h-4" />
                        </button>

                        {booking.status !== 'completed' && booking.status !== 'cancelled' && (
                          <button
                            onClick={() => handleOpenCancelModal(booking)}
                            title="Force Cancel & Refund"
                            className="p-1.5 text-slate-500 hover:text-rose-700 hover:bg-rose-50 rounded-lg transition-colors"
                          >
                            <XCircle className="w-4 h-4" />
                          </button>
                        )}

                        <button
                          onClick={() => handleDeleteBooking(booking.id)}
                          title="Delete / Purge Record"
                          className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
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

      {/* Booking Details Modal */}
      {selectedBooking && (
        <Modal
          isOpen={Boolean(selectedBooking)}
          onClose={() => setSelectedBooking(null)}
          title={`Booking Details #${selectedBooking.id.substring(0, 10)}`}
          subtitle="Full reservation payload and partner coordinates"
        >
          <div className="space-y-6 text-xs text-slate-700">
            {/* Header info card */}
            <div className="p-4 rounded-xl bg-purple-50/60 border border-purple-100 flex items-center justify-between">
              <div>
                <span className="text-[11px] font-bold text-purple-700 block">Total Amount Paid</span>
                <span className="text-2xl font-extrabold text-slate-900">₹{selectedBooking.totalAmount}</span>
              </div>
              <StatusBadge status={selectedBooking.status} />
            </div>

            {/* Grid attributes */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">PARKING LOCATION</label>
                <p className="font-bold text-slate-900">{selectedBooking.spaceTitle}</p>
                <p className="text-slate-500 mt-0.5">{selectedBooking.spaceAddress}</p>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">DATE & TIME</label>
                <p className="font-bold text-slate-900">{selectedBooking.bookingDate}</p>
                <p className="text-slate-500 mt-0.5">{selectedBooking.timeSlot}</p>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">VEHICLE SPECS</label>
                <p className="font-bold text-slate-900">{selectedBooking.vehicleNumber}</p>
                <p className="text-slate-500 mt-0.5">
                  {selectedBooking.vehicleModel} ({selectedBooking.vehicleType.toUpperCase()})
                </p>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-400 block mb-1">CUSTOMER USER ID</label>
                <p className="font-mono text-slate-800 bg-slate-100 p-1.5 rounded text-[11px] break-all">
                  {selectedBooking.userId}
                </p>
              </div>
            </div>

            {/* Ratings & Review if available */}
            {selectedBooking.userRating !== undefined && (
              <div className="p-3 bg-amber-50/60 border border-amber-100 rounded-xl">
                <span className="text-[11px] font-bold text-amber-700 block">Customer Rating</span>
                <p className="font-bold text-slate-800 mt-0.5">⭐ {selectedBooking.userRating} / 5.0</p>
                {selectedBooking.userReview && (
                  <p className="text-slate-600 italic mt-1">"{selectedBooking.userReview}"</p>
                )}
              </div>
            )}

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                onClick={() => setSelectedBooking(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Force Cancel & Refund Modal */}
      {cancelModalBooking && (
        <Modal
          isOpen={Boolean(cancelModalBooking)}
          onClose={() => setCancelModalBooking(null)}
          title="Force Cancel Booking & Process Refund"
          subtitle={`Cancelling reservation for ${cancelModalBooking.vehicleNumber} at ${cancelModalBooking.spaceTitle}`}
        >
          <div className="space-y-4 text-xs">
            <div className="p-3.5 bg-rose-50 border border-rose-100 rounded-xl flex items-center gap-3 text-rose-800">
              <AlertTriangle className="w-5 h-5 shrink-0" />
              <p>
                This action will mark the booking as <strong>Cancelled</strong> and instantly credit the refund amount directly to the customer's wallet balance in Firebase RTDB.
              </p>
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">
                Refund Amount (₹) - Max ₹{cancelModalBooking.totalAmount}
              </label>
              <input
                type="number"
                value={refundAmount}
                onChange={(e) => setRefundAmount(Number(e.target.value))}
                max={cancelModalBooking.totalAmount}
                min={0}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 font-bold focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
              />
            </div>

            <div>
              <label className="font-bold text-slate-700 block mb-1.5">
                Cancellation Reason / Resolution Note
              </label>
              <input
                type="text"
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                placeholder="Reason for cancellation..."
                className="w-full bg-slate-50 border border-slate-200 rounded-xl p-2.5 text-xs text-slate-900 focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500"
              />
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setCancelModalBooking(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Dismiss
              </button>
              <button
                type="button"
                onClick={handleExecuteCancel}
                disabled={isProcessing}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white font-bold rounded-xl text-xs flex items-center gap-1.5 shadow-sm"
              >
                {isProcessing ? 'Processing Refund...' : 'Confirm Cancellation & Refund'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
