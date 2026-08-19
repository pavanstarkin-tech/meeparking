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
  final Map<String, int> _optimisticRatings = {};

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
                    final filtered = allBookings
                        .where((b) => b.computedStatus == _selectedTab)
                        .toList();

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
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, String key) {
    final bool isSelected = _selectedTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineRatingStars(Booking booking) {
    final currentRating = _optimisticRatings[booking.id] ?? (booking.userRating?.round() ?? 0);
    final hasRated = currentRating > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasRated)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              'Rate: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            final isFilled = starIndex <= currentRating;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                setState(() {
                  _optimisticRatings[booking.id] = starIndex;
                });

                final success = await FirebaseRtdbService.submitBookingRating(
                  bookingId: booking.id,
                  spaceId: booking.spaceId,
                  rating: starIndex.toDouble(),
                );

                if (mounted) {
                  ref.invalidate(userBookingsProvider);
                  if (success) {
                    _showTopToast('⭐ Rated $starIndex / 5 Stars! Thank you.');
                  } else {
                    _showTopToast('Failed to submit rating. Please try again.', isError: true);
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 4),
                child: AnimatedScale(
                  scale: isFilled ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 26,
                    color: isFilled ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                  ),
                ),
              ),
            );
          }),
        ),
        if (hasRated) ...[
          const SizedBox(width: 5),
          Text(
            '$currentRating.0 ★',
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                    Text(
                      booking.spaceTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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

              // 3-Dots Menu for Upcoming Bookings (Cancel Booking)
              if (isUpcoming) ...[
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondaryLight, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                  onSelected: (value) {
                    if (value == 'cancel') {
                      _showCancelBookingDialog(booking);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: AppColors.redError, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Cancel Booking',
                            style: TextStyle(
                              color: AppColors.redError,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Call, Chat & Map for upcoming bookings
          if (isUpcoming) ...[
            Row(
              children: [
                // Call Owner Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CallScreen(
                            partnerName: booking.spaceTitle,
                            partnerRole: 'Space Owner',
                            subtitle: booking.spaceAddress,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_outlined, size: 15, color: AppColors.primary),
                    label: const Text('Call', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Chat Owner Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            partnerId: booking.partnerId,
                            partnerName: 'Space Owner (${booking.spaceTitle})',
                            partnerPhotoUrl: '',
                            spaceTitle: booking.spaceTitle,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.primary),
                    label: const Text('Chat', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Navigate Map Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NavigationScreen(booking: booking),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation_outlined, size: 15, color: Colors.white),
                    label: const Text('Map', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Completed or Cancelled state: Show 5-Star Rating row or vehicle / status info
            const Divider(height: 20, color: Color(0xFFF3F4F6)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (booking.computedStatus == 'completed')
                  _buildInlineRatingStars(booking)
                else
                  Text(
                    booking.vehicleNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: booking.computedStatus == 'completed'
                        ? AppColors.greenSuccess.withOpacity(0.15)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.computedStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: booking.computedStatus == 'completed'
                          ? AppColors.greenSuccess
                          : AppColors.redError,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
