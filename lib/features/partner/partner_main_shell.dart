import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_providers.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import 'earnings_screen.dart';
import 'my_listings_screen.dart';
import 'partner_booking_card.dart';
import 'partner_dashboard_screen.dart';
import 'partner_onboarding_wizard.dart';

class PartnerMainShell extends ConsumerStatefulWidget {
  const PartnerMainShell({super.key});

  @override
  ConsumerState<PartnerMainShell> createState() => _PartnerMainShellState();
}

class _PartnerMainShellState extends ConsumerState<PartnerMainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const PartnerDashboardScreen(),
      const MyListingsScreen(),
      const PartnerBookingsPage(),
      const EarningsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex.clamp(0, pages.length - 1),
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex.clamp(0, pages.length - 1),
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.maps_home_work_outlined),
            activeIcon: Icon(Icons.maps_home_work),
            label: 'Listings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border_outlined),
            activeIcon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// PAGE 1: Partner Bookings Page (Home on Partner Side)
class PartnerBookingsPage extends ConsumerWidget {
  const PartnerBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: StreamBuilder<List<Booking>>(
        stream: FirebaseRtdbService.streamPartnerBookings(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3E8FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bookmark_border, size: 56, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No bookings yet',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When customers reserve your listed parking spots, their booking details will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              return PartnerBookingCard(booking: bookings[index]);
            },
          );
        },
      ),
    ),
  );
}
}

// PAGE 3: Partner Profile Page
class PartnerProfilePage extends ConsumerStatefulWidget {
  const PartnerProfilePage({super.key});

  @override
  ConsumerState<PartnerProfilePage> createState() => _PartnerProfilePageState();
}

class _PartnerProfilePageState extends ConsumerState<PartnerProfilePage> {
  bool _isUploadingPhoto = false;

  void _pickAndUpdateProfilePhoto() async {
    final imageFile = await CloudinaryService.pickImage();
    if (imageFile == null) return;

    setState(() => _isUploadingPhoto = true);
    final uploadedUrl = await CloudinaryService.uploadImage(imageFile);

    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      final user = ref.read(userProfileProvider);
      // Persist photo URL in Realtime Database under user UID
      await FirebaseRtdbService.updateUserProfile(user.uid, {'photoUrl': uploadedUrl});

      // Update local state
      ref.read(userProfileProvider.notifier).state = user.copyWith(photoUrl: uploadedUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: AppColors.greenSuccess,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: StreamBuilder<List<ParkingSpace>>(
        stream: FirebaseRtdbService.streamPartnerSpaces(user.uid),
        builder: (context, snapshot) {
          final spaces = snapshot.data ?? [];
          final activeCount = spaces.where((s) => s.isActive).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Profile Card Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: const Color(0xFFF3E8FF),
                            backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                            child: user.photoUrl.isEmpty ? const Icon(Icons.person, size: 50, color: AppColors.primary) : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingPhoto ? null : _pickAndUpdateProfilePhoto,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name.isNotEmpty ? user.name : 'Partner User',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [if (user.phone.isNotEmpty) user.phone, if (user.email.isNotEmpty) user.email].join(' • '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(height: 10),
                      Chip(
                        label: Text(
                          activeCount > 0 ? 'Verified Partner • $activeCount Active Spots' : 'Partner Account Active',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 20),

            // Profile Actions List
            _buildProfileTile(
              icon: Icons.list_alt,
              title: 'My Parking Listings',
              subtitle: 'Manage active spots, pricing & availability',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyListingsScreen()),
                );
              },
            ),
            _buildProfileTile(
              icon: Icons.add_circle_outline,
              title: 'Add New Parking Spot',
              subtitle: 'Register another driveway or garage location',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PartnerOnboardingWizard()),
                );
              },
            ),
            _buildProfileTile(
              icon: Icons.directions_car_outlined,
              title: 'My Personal Vehicles',
              subtitle: 'Manage registered cars & bikes for seeker mode',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vehicles configuration updated.')),
                );
              },
            ),
            _buildProfileTile(
              icon: Icons.swap_horiz,
              title: 'Switch to User Mode (Seeker)',
              subtitle: 'Search & reserve parking as a customer',
              onTap: () {
                ref.read(currentRoleProvider.notifier).state = 'user';
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
            _buildProfileTile(
              icon: Icons.logout,
              title: 'Log Out',
              subtitle: 'Sign out from your partner account',
              iconColor: AppColors.redError,
              onTap: () async {
                await AuthService.signOut();
                ref.read(userProfileProvider.notifier).state = UserProfile(
                  uid: '',
                  name: '',
                  email: '',
                  phone: '',
                  photoUrl: '',
                  role: 'user',
                  walletBalance: 0.0,
                  fcmToken: '',
                  vehicles: [],
                  createdAt: DateTime.now(),
                );
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            ],
          ),
        );
      },
    ),
  ),
);
}

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
