import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/booking.dart';
import '../../shared/providers/app_providers.dart';
import '../navigation/navigation_screen.dart';
import '../chat/chat_screen.dart';
import '../chat/call_screen.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  String _selectedTab = 'upcoming'; // 'upcoming' | 'completed' | 'cancelled'

  void _showTopToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.redError : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 120,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showCancelBookingDialog(Booking booking) {
    final refundInfo = booking.calculateRefund();
    bool isCancelling = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cancel_outlined, color: AppColors.redError, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cancel Parking Booking?',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Review the refund policy calculation below',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Booking Details Container
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildRefundRow('Parking Space', booking.spaceTitle),
                        const Divider(height: 16),
                        _buildRefundRow('Time Slot', '${booking.bookingDate}, ${booking.timeSlot}'),
                        const Divider(height: 16),
                        _buildRefundRow('Booking Amount', '₹${booking.totalAmount.toStringAsFixed(1)}'),
                        const Divider(height: 16),
                        _buildRefundRow(
                          'Time Until Booking',
                          refundInfo.hoursUntilStart > 0
                              ? '${refundInfo.hoursUntilStart.toStringAsFixed(1)} hrs left'
                              : 'Already Started',
                          valueColor: refundInfo.hoursUntilStart >= 24 ? AppColors.greenSuccess : Colors.orange.shade800,
                        ),
                        const Divider(height: 16),
                        _buildRefundRow(
                          'Refund Rate',
                          '${refundInfo.refundPercent.toInt()}%',
                          valueColor: refundInfo.refundPercent == 100
                              ? AppColors.greenSuccess
                              : (refundInfo.refundPercent > 0 ? Colors.orange.shade800 : AppColors.redError),
                        ),
                        const Divider(height: 16),
                        _buildRefundRow(
                          'Refund to Wallet',
                          '₹${refundInfo.refundAmount.toStringAsFixed(1)}',
                          isBold: true,
                          valueColor: AppColors.greenSuccess,
                        ),
                        if (refundInfo.deductionAmount > 0) ...[
                          const Divider(height: 16),
                          _buildRefundRow(
                            'Cancellation Fee (7%/2hr)',
                            '- ₹${refundInfo.deductionAmount.toStringAsFixed(1)}',
                            valueColor: AppColors.redError,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Policy Explanation Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '100% full refund if cancelled 24+ hrs before start time. Within 24 hrs, 7% is deducted for every 2 hours closer to start time.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Keep Booking',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isCancelling
                              ? null
                              : () async {
                                  final nav = Navigator.of(context);
                                  setModalState(() => isCancelling = true);
                                  final res = await FirebaseRtdbService.cancelBooking(booking: booking);
                                  nav.pop();
                                  if (mounted) {
                                    ref.invalidate(userBookingsProvider);
                                    ref.invalidate(walletBalanceStreamProvider);
                                    ref.invalidate(walletTransactionsProvider);
                                    if (res.success) {
                                      _showTopToast(res.message);
                                      setState(() => _selectedTab = 'cancelled');
                                    } else {
                                      _showTopToast(res.message, isError: true);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.redError,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: isCancelling
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Confirm Cancel',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRefundRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade700,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Segmented Tab Selector
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  _buildTab('Upcoming', 'upcoming'),
                  _buildTab('Completed', 'completed'),
                  _buildTab('Cancelled', 'cancelled'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Booking List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(userBookingsProvider);
                },
                child: bookingsAsync.when(
                  data: (allBookings) {
                    final filtered = allBookings.where((b) {
                      if (_selectedTab == 'upcoming') {
                        return b.computedStatus == 'upcoming' || b.computedStatus == 'parked';
                      }
                      return b.computedStatus == _selectedTab;
                    }).toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'No $_selectedTab bookings',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondaryLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final booking = filtered[index];
                        return _buildBookingCard(booking);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (_, __) => const Center(
                    child: Text('Failed to load bookings'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String tabKey) {
    final isSelected = _selectedTab == tabKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tabKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineRatingStars(Booking booking) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: () async {
              final success = await FirebaseRtdbService.submitBookingRating(
                bookingId: booking.id,
                spaceId: booking.spaceId,
                rating: i.toDouble(),
              );
              if (mounted && success) ref.invalidate(userBookingsProvider);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Icon(
                Icons.star_rounded,
                size: 20,
                color: (booking.userRating != null && i <= booking.userRating!)
                    ? const Color(0xFFF59E0B)
                    : Colors.grey.shade300,
              ),
            ),
          ),
        if (booking.userRating != null && booking.userRating! > 0) ...[
          const SizedBox(width: 4),
          Text(
            booking.userRating!.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD97706),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final bool isUpcoming = booking.computedStatus == 'upcoming';
    final bool isParked = booking.computedStatus == 'parked';
    final bool isActiveParking = isUpcoming || isParked;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isParked ? AppColors.greenSuccess.withOpacity(0.4) : Colors.grey.shade200,
          width: isParked ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isParked ? AppColors.greenSuccess.withOpacity(0.08) : Colors.black.withOpacity(0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?auto=format&fit=crop&w=200&q=80',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.purple.shade50,
                    child: const Icon(Icons.local_parking, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            booking.spaceTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isParked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.greenSuccess.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'PARKED',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.greenSuccess),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      booking.spaceAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${booking.bookingDate}, ${booking.timeSlot}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUpcoming)
                IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondaryLight, size: 20),
                  onPressed: () => _showCancelBookingDialog(booking),
                  tooltip: 'Cancel Booking',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // In-App OTP Badge for Seeker
          if (isActiveParking) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isParked ? const Color(0xFFECFDF5) : const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isParked ? AppColors.greenSuccess.withOpacity(0.3) : AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isParked ? Icons.check_circle_outline : Icons.pin_outlined,
                        size: 18,
                        color: isParked ? AppColors.greenSuccess : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isParked ? 'Exit / Completion OTP:' : 'Entry Check-in OTP:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isParked ? AppColors.greenSuccess : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isParked ? booking.exitOtp : booking.entryOtp,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: isParked ? AppColors.greenSuccess : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action Buttons: Call, Chat, Map, and Check-in / Complete Parking
          if (isActiveParking) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallScreen(partnerId: booking.partnerId, partnerName: 'Owner', partnerRole: 'Space Owner', subtitle: booking.spaceAddress))),
                    icon: const Icon(Icons.phone_outlined, size: 15, color: AppColors.primary),
                    label: const Text('Call', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(partnerId: booking.partnerId, partnerName: 'Owner', spaceTitle: booking.spaceTitle, partnerRole: 'Space Owner'))),
                    icon: const Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.primary),
                    label: const Text('Chat', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NavigationScreen(booking: booking))),
                    icon: const Icon(Icons.navigation_outlined, size: 15, color: Colors.white),
                    label: const Text('Map', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (isUpcoming) {
                    await FirebaseRtdbService.verifyBookingEntryOtp(booking.id, booking.entryOtp);
                    if (mounted) {
                      ref.invalidate(userBookingsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚗 Parking Started! Vehicle marked as Parked.'), backgroundColor: AppColors.greenSuccess));
                    }
                  } else if (isParked) {
                    await FirebaseRtdbService.completeBookingParking(booking.id);
                    if (mounted) {
                      ref.invalidate(userBookingsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Parking Completed! Thank you for using MeeParking.'), backgroundColor: AppColors.greenSuccess));
                    }
                  }
                },
                icon: Icon(isParked ? Icons.check_circle : Icons.local_parking_rounded, size: 16, color: Colors.white),
                label: Text(isParked ? 'Mark Parking as Completed' : 'Arrived at Spot (Start Parking)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: isParked ? const Color(0xFF10B981) : const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8), elevation: 0),
              ),
            ),
          ] else ...[
            const Divider(height: 20, color: Color(0xFFF3F4F6)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (booking.computedStatus == 'completed') _buildInlineRatingStars(booking) else Text(booking.vehicleNumber, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: booking.computedStatus == 'completed' ? AppColors.greenSuccess.withOpacity(0.15) : Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(booking.computedStatus.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: booking.computedStatus == 'completed' ? AppColors.greenSuccess : AppColors.redError)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
