import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/providers/app_providers.dart';
import 'package:flutter/services.dart';
import '../search/search_parking_screen.dart';
import '../parking/parking_details_screen.dart';
import '../bookings/my_bookings_screen.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
import '../saved/saved_spots_screen.dart';
import '../partner/become_partner_screen.dart';
import '../partner/partner_dashboard_screen.dart';
import '../partner/my_listings_screen.dart';
import '../partner/earnings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0;
  late final PageController _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  double? _userLat;
  double? _userLng;
  bool _showAllSpotsFallback = false;
  bool _hasUnreadNotifications = true;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController(initialPage: 1000, viewportFraction: 0.93);
    _startBannerAutoScroll();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      if (mounted) setState(() { _userLat = pos.latitude; _userLng = pos.longitude; });
    } catch (_) {}
  }

  double? _getDistanceKm(double spaceLat, double spaceLng) {
    if (_userLat == null || _userLng == null) return null;
    const R = 6371.0;
    final dLat = (spaceLat - _userLat!) * math.pi / 180;
    final dLng = (spaceLng - _userLng!) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_userLat! * math.pi / 180) * math.cos(spaceLat * math.pi / 180) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final dist = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return dist;
  }

  String _distanceLabel(double spaceLat, double spaceLng) {
    final dist = _getDistanceKm(spaceLat, spaceLng);
    if (dist == null) return '';
    if (dist < 1) return '${(dist * 1000).round()} m';
    return '${dist.toStringAsFixed(1)} km';
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 3, milliseconds: 500), (timer) {
      if (_bannerPageController.hasClients) {
        _bannerPageController.nextPage(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);

    // If Partner role, show Partner Navigation Shell
    if (role == 'partner') {
      return _buildPartnerShell();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: IndexedStack(
        index: _selectedTab.clamp(0, 3),
        children: [
          _buildUserHomeTab(),
          const MyBookingsScreen(),
          const WalletScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildUserBottomNav(),
    );
  }

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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<Map<String, dynamic>> _getRealNotifications() {
    final notifications = <Map<String, dynamic>>[];

    // 1. Real Bookings from RTDB
    final bookingsAsync = ref.read(userBookingsProvider);
    bookingsAsync.whenData((bookings) {
      for (final b in bookings) {
        final bTimestamp = DateTime.tryParse(b.createdAt)?.millisecondsSinceEpoch ?? 0;
        if (b.status.toLowerCase() == 'cancelled') {
          notifications.add({
            'icon': Icons.cancel_outlined,
            'iconColor': AppColors.redError,
            'title': 'Booking Cancelled',
            'body': 'Reservation for ${b.vehicleNumber} at ${b.spaceTitle} was cancelled.',
            'time': '${b.bookingDate}, ${b.timeSlot}',
            'timestamp': bTimestamp,
          });
        } else if (b.computedStatus == 'completed') {
          notifications.add({
            'icon': Icons.task_alt_rounded,
            'iconColor': AppColors.greenSuccess,
            'title': 'Booking Completed',
            'body': 'Completed parking at ${b.spaceTitle}.',
            'time': '${b.bookingDate}, ${b.timeSlot}',
            'timestamp': bTimestamp,
          });
        } else {
          notifications.add({
            'icon': Icons.confirmation_number_outlined,
            'iconColor': AppColors.primary,
            'title': 'Parking Reserved',
            'body': 'Upcoming slot booked for ${b.vehicleNumber} at ${b.spaceTitle}.',
            'time': '${b.bookingDate}, ${b.timeSlot}',
            'timestamp': bTimestamp,
          });
        }
      }
    });

    // 2. Real Wallet Transactions from RTDB
    final walletTxAsync = ref.read(walletTransactionsProvider);
    walletTxAsync.whenData((txs) {
      for (final tx in txs) {
        notifications.add({
          'icon': tx.type == 'credit' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          'iconColor': tx.type == 'credit' ? AppColors.greenSuccess : Colors.blue,
          'title': tx.title.isNotEmpty ? tx.title : (tx.type == 'credit' ? 'Wallet Credited' : 'Wallet Debited'),
          'body': '₹${tx.amount.toStringAsFixed(1)} - ${tx.subtitle}',
          'time': tx.date,
          'timestamp': tx.timestamp,
        });
      }
    });

    // Sort strictly newest first
    notifications.sort((a, b) {
      final tA = a['timestamp'] as int? ?? 0;
      final tB = b['timestamp'] as int? ?? 0;
      return tB.compareTo(tA);
    });

    return notifications;
  }

  void _showNotificationsSheet(BuildContext context) {
    final realNotifs = _getRealNotifications();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Notifications',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_hasUnreadNotifications && realNotifs.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() => _hasUnreadNotifications = false);
                            setSheetState(() {});
                            _showTopToast('All notifications marked as read');
                          },
                          child: const Text('Mark all read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Real Notifications List or Clean Empty State (NO FAKE NOTIFICATIONS)
                  if (realNotifs.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.notifications_none_rounded, size: 40, color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'When you book a parking spot, make a payment, or receive a refund, your real updates will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.35),
                          ),
                        ],
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: realNotifs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = realNotifs[index];
                          return _buildNotificationItem(
                            icon: item['icon'] as IconData,
                            iconColor: item['iconColor'] as Color,
                            title: item['title'] as String,
                            body: item['body'] as String,
                            time: item['time'] as String,
                            isUnread: _hasUnreadNotifications,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread ? iconColor.withOpacity(0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUnread ? iconColor.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      time,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOffersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
              const Row(
                children: [
                  Icon(Icons.local_offer_outlined, color: Colors.purple, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Exclusive Parking Offers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Copy promo codes and apply them at checkout for instant discounts.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 18),

              // Coupon 1
              _buildCouponCard(
                code: 'FIRST50',
                title: '50% OFF First Booking',
                subtitle: 'Get 50% discount up to ₹100 on your first parking reservation.',
                gradient: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
              ),
              const SizedBox(height: 10),

              // Coupon 2
              _buildCouponCard(
                code: 'WEEKEND20',
                title: '20% OFF Weekend Parking',
                subtitle: 'Save 20% on all Saturday & Sunday parking spot bookings.',
                gradient: const [Color(0xFF2563EB), Color(0xFF1E40AF)],
              ),
              const SizedBox(height: 10),

              // Coupon 3
              _buildCouponCard(
                code: 'EVFAST50',
                title: '₹50 OFF EV Charging',
                subtitle: 'Flat ₹50 discount on EV charging enabled parking spaces.',
                gradient: const [Color(0xFF059669), Color(0xFF047857)],
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Search & Book Parking',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCouponCard({
    required String code,
    required String title,
    required String subtitle,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: gradient.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              _showTopToast('Promo code $code copied to clipboard! 📋');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    code,
                    style: TextStyle(color: gradient.first, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.copy_rounded, color: gradient.first, size: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHomeTab() {
    final user = ref.watch(userProfileProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: User Greeting, Profile Avatar & Location
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedTab = 3),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF6366F1),
                        backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                        child: user.photoUrl.isEmpty
                            ? Text(
                                user.name.isNotEmpty ? user.name.trim().substring(0, 1).toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${user.name.split(' ').first}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const Row(
                            children: [
                              Text(
                                'Find your perfect parking space',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Notification Bell Badge
                GestureDetector(
                  onTap: () => _showNotificationsSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        const Icon(Icons.notifications_outlined, color: AppColors.textPrimaryLight),
                        if (_hasUnreadNotifications && _getRealNotifications().isNotEmpty)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.redError,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text(
                      'Search location',
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Infinite Auto-Sliding Carousel for 2 Cards (Find Parking & EV Charging)
            Column(
              children: [
                SizedBox(
                  height: 155,
                  child: PageView.builder(
                    controller: _bannerPageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentBannerIndex = index % 2;
                      });
                    },
                    itemBuilder: (context, index) {
                      final cardIndex = index % 2;
                      if (cardIndex == 0) {
                        // Card 0: Find Parking Card
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x337C3AED),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: 5,
                                    bottom: -8,
                                    top: -8,
                                    child: Image.asset(
                                      'assets/new-assets/parking.png',
                                      width: 145,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.directions_car,
                                        color: Colors.white24,
                                        size: 70,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: SizedBox(
                                      width: 165,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Find Parking',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Find & book parking in seconds',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Book Spot',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Card 1: EV Charging Card
                        return GestureDetector(
                          onTap: () {
                            ref.read(evFilterProvider.notifier).state = true;
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5E258D), Color(0xFF3B155B)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x335E258D),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: 2,
                                    bottom: -8,
                                    top: -8,
                                    child: Image.asset(
                                      'assets/new-assets/ev charging.png',
                                      width: 130,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.ev_station,
                                        color: Colors.white24,
                                        size: 70,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: SizedBox(
                                      width: 165,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'EV Charging',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Locate fast EV charging stations near you',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Explore EV',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Carousel Dots Indicator (2 Dots)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(2, (index) {
                    final bool isActive = _currentBannerIndex == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Action Pills
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickPill('Offers', Icons.local_offer_outlined, Colors.purple, () {
                  _showOffersSheet(context);
                }),
                _buildQuickPill('Favourites', Icons.favorite_border, Colors.pink, () {
                  SavedSpotsBottomSheet.show(context);
                }),
                _buildQuickPill('Recent', Icons.history, Colors.blue, () {
                  setState(() => _selectedTab = 1);
                }),
                _buildQuickPill('Partner', Icons.storefront_outlined, AppColors.primary, () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BecomePartnerScreen()),
                  );
                }),
              ],
            ),
            const SizedBox(height: 28),

            // Popular Locations Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Popular Locations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
                    );
                  },
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Real Available Parking Spaces Horizontal Scroll
            SizedBox(
              height: 140,
              child: StreamBuilder<List<ParkingSpace>>(
                stream: FirebaseRtdbService.streamParkingSpaces(),
                builder: (context, snapshot) {
                  final allSpaces = snapshot.data ?? [];
                  final spaces = allSpaces.where((s) => s.polygonCoordinates != null && s.polygonCoordinates!.length >= 3).toList();
                  if (spaces.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          'No partner parking spots listed yet. Tap Partner to add one!',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                      ),
                    );
                  }

                  // Sort closest first
                  if (_userLat != null && _userLng != null) {
                    spaces.sort((a, b) {
                      final dA = _getDistanceKm(a.lat, a.lng) ?? 9999.0;
                      final dB = _getDistanceKm(b.lat, b.lng) ?? 9999.0;
                      return dA.compareTo(dB);
                    });
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: spaces.length,
                    itemBuilder: (ctx, idx) {
                      final s = spaces[idx];
                      return _buildPopularCard(s);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // Nearby Parking Spots Vertical Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nearby Available Parking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.near_me, size: 12, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Up to 39 km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            StreamBuilder<List<ParkingSpace>>(
              stream: FirebaseRtdbService.streamParkingSpaces(),
              builder: (context, snapshot) {
                final allSpaces = snapshot.data ?? [];
                final validSpaces = allSpaces.where((s) => s.polygonCoordinates != null && s.polygonCoordinates!.length >= 3).toList();
                if (validSpaces.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Listings added by partners will display here in real-time.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 1. Sort all spaces by proximity (closest first)
                if (_userLat != null && _userLng != null) {
                  validSpaces.sort((a, b) {
                    final dA = _getDistanceKm(a.lat, a.lng) ?? 9999.0;
                    final dB = _getDistanceKm(b.lat, b.lng) ?? 9999.0;
                    return dA.compareTo(dB);
                  });
                }

                // 2. Filter spaces within 39 km of user location
                final within39KmSpaces = (_userLat != null && _userLng != null)
                    ? validSpaces.where((s) {
                        final dist = _getDistanceKm(s.lat, s.lng);
                        return dist != null && dist <= 39.0;
                      }).toList()
                    : validSpaces;

                // 3. If no spaces within 39 km, show informative fallback
                if (within39KmSpaces.isEmpty && !_showAllSpotsFallback) {
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_off, color: Color(0xFFD97706), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'No parking spots within 39 km of your live GPS location.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _showAllSpotsFallback = true),
                            icon: const Icon(Icons.map_outlined, size: 16, color: AppColors.primary),
                            label: Text(
                              'Show all available parking spots (${validSpaces.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final displaySpaces = within39KmSpaces.isNotEmpty ? within39KmSpaces : validSpaces;

                return Column(
                  children: displaySpaces.map((s) => _buildNearbyParkingCard(s)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyParkingCard(ParkingSpace space) {
    final title = space.title;
    final address = space.address;
    final List<double> prices = [
      space.pricing.twoWheeler.hourly,
      space.pricing.threeWheeler.hourly,
      space.pricing.fourWheeler.hourly,
    ].where((p) => p > 0).toList();
    final int minPrice = prices.isNotEmpty ? prices.reduce((a, b) => a < b ? a : b).toInt() : 0;
    final rate = minPrice > 0 ? minPrice.toString() : space.pricing.fourWheeler.hourly.toStringAsFixed(0);
    final isEv = space.isEvChargingAvailable;
    final String image = space.images.isNotEmpty
        ? space.images.first
        : 'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?auto=format&fit=crop&w=400&q=80';
    final distLabel = _distanceLabel(space.lat, space.lng);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParkingDetailsScreen(spaceId: space.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildSafeImage(image, width: 80, height: 80),
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
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isEv)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: AppColors.greenSuccess.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.bolt, color: AppColors.greenSuccess, size: 12),
                              Text(
                                'EV',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.greenSuccess),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹$rate / hr',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      // Distance chip
                      if (distLabel.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.near_me_outlined, size: 12, color: AppColors.textSecondaryLight),
                            const SizedBox(width: 2),
                            Text(
                              distLabel,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGradient.colors.first.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Book Spot',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPill(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCard(ParkingSpace space) {
    final List<double> prices = [
      space.pricing.twoWheeler.hourly,
      space.pricing.threeWheeler.hourly,
      space.pricing.fourWheeler.hourly,
    ].where((p) => p > 0).toList();
    final int minPrice = prices.isNotEmpty ? prices.reduce((a, b) => a < b ? a : b).toInt() : 0;
    final distLabel = _distanceLabel(space.lat, space.lng);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParkingDetailsScreen(spaceId: space.id),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildSafeImage(space.images.isNotEmpty ? space.images.first : '', fit: BoxFit.cover),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.80), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price/hr + Distance row only
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (minPrice > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '₹$minPrice/hr',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (distLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.near_me, size: 10, color: Colors.white70),
                                const SizedBox(width: 2),
                                Text(
                                  distLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedTab.clamp(0, 3),
      onTap: (idx) => setState(() => _selectedTab = idx),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondaryLight,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Bookings'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }

  // Partner Navigation Shell (when in Partner Mode)
  Widget _buildPartnerShell() {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab.clamp(0, 4),
        children: [
          const PartnerDashboardScreen(),
          const MyListingsScreen(),
          const MyBookingsScreen(),
          const EarningsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab.clamp(0, 4),
        onTap: (idx) => setState(() => _selectedTab = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Listings'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'More'),
        ],
      ),
    );
  }

  Widget _buildSafeImage(String imageSource, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (imageSource.startsWith('data:image') || (!imageSource.startsWith('http') && imageSource.length > 100)) {
      try {
        final base64Str = imageSource.contains(',') ? imageSource.split(',').last : imageSource;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            width: width,
            height: height,
            color: Colors.purple.shade50,
            child: const Icon(Icons.local_parking, color: AppColors.primary, size: 32),
          ),
        );
      } catch (_) {
        return Container(
          width: width,
          height: height,
          color: Colors.purple.shade50,
          child: const Icon(Icons.local_parking, color: AppColors.primary, size: 32),
        );
      }
    }

    if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      return Image.network(
        imageSource,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.purple.shade50,
          child: const Icon(Icons.local_parking, color: AppColors.primary, size: 32),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      color: Colors.purple.shade50,
      child: const Icon(Icons.local_parking, color: AppColors.primary, size: 32),
    );
  }
}
