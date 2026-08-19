import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/providers/app_providers.dart';
import 'my_listings_screen.dart';
import 'partner_booking_card.dart';

class PartnerDashboardScreen extends ConsumerWidget {
  const PartnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: StreamBuilder<List<ParkingSpace>>(
        stream: FirebaseRtdbService.streamPartnerSpaces(user.uid),
        builder: (context, spacesSnap) {
          final spaces = spacesSnap.data ?? [];
          final totalListings = spaces.length;

          return StreamBuilder<List<Booking>>(
            stream: FirebaseRtdbService.streamPartnerBookings(user.uid),
            builder: (context, bookingsSnap) {
              final bookings = bookingsSnap.data ?? [];
              final totalBookings = bookings.length;
              final totalEarnings = bookings.fold<double>(0.0, (sum, b) => sum + b.totalAmount);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Header Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFF3E8FF),
                          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                          child: user.photoUrl.isEmpty ? const Icon(Icons.person, size: 24, color: AppColors.primary) : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              user.name.isNotEmpty ? user.name : 'Partner User',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4 Dynamic Stats Cards Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.6,
                      children: [
                        _buildStatCard(
                          'Total Listings',
                          '$totalListings',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MyListingsScreen()),
                            );
                          },
                        ),
                        _buildStatCard('Total Bookings', '$totalBookings'),
                        _buildStatCard('Total Earnings', '₹${totalEarnings.toStringAsFixed(0)}'),
                        _buildStatCard('Active Spots', '${spaces.where((s) => s.isActive).length}'),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Recent Bookings Header & Real Stream List
                    const Text(
                      'Recent Customer Bookings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (bookings.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.inbox, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No bookings recorded yet',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Customer reservations for your parking spots will show up here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...bookings.take(5).map((b) => PartnerBookingCard(booking: b)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

  Widget _buildStatCard(String title, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
