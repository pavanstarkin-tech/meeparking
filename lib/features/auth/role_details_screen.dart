import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_providers.dart';
import '../home/home_screen.dart';
import '../partner/partner_onboarding_wizard.dart';

class RoleDetailsScreen extends ConsumerStatefulWidget {
  final String role; // 'user' (Seeker) or 'partner' (Owner)

  const RoleDetailsScreen({
    super.key,
    required this.role,
  });

  @override
  ConsumerState<RoleDetailsScreen> createState() => _RoleDetailsScreenState();
}

class _RoleDetailsScreenState extends ConsumerState<RoleDetailsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Seeker Specific Controllers
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  String _selectedVehicleType = '4-Wheeler'; // '2-Wheeler', '3-Wheeler', '4-Wheeler'

  // Partner Specific Controllers
  final _businessNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '5');

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentAuth = AuthService.currentUser;
    if (currentAuth?.displayName != null && currentAuth!.displayName!.isNotEmpty) {
      _nameCtrl.text = currentAuth.displayName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _businessNameCtrl.dispose();
    _cityCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndProceed() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your full name.'),
          backgroundColor: AppColors.redError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (widget.role == 'user') {
      final model = _vehicleModelCtrl.text.trim();

      if (model.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your vehicle make & model.'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    } else {
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Phone number is required for partner verification.'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      final businessName = _businessNameCtrl.text.trim();
      if (businessName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your property/space name.'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      final city = _cityCtrl.text.trim();
      if (city.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your city/area.'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = AuthService.currentUser;
      final uid = user?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      final email = user?.email ?? '';

      // Update Firebase Auth Display Name
      await AuthService.updateDisplayName(name);

      if (widget.role == 'user') {
        final model = _vehicleModelCtrl.text.trim();
        final regNo = _vehicleNumberCtrl.text.trim().toUpperCase();

        final vehicle = Vehicle(
          id: 'veh_${DateTime.now().millisecondsSinceEpoch}',
          number: regNo.isNotEmpty ? regNo : 'Vehicle',
          model: model,
          type: _selectedVehicleType == '2-Wheeler' ? '2-Wheeler' : (_selectedVehicleType == '3-Wheeler' ? '3-Wheeler' : '4-Wheeler'),
        );

        final profilePayload = {
          'uid': uid,
          'name': name,
          'email': email,
          'phone': phone,
          'role': 'user',
          'photoUrl': user?.photoURL ?? '',
          'walletBalance': 0.0,
          'createdAt': DateTime.now().toIso8601String(),
          'vehicles': [vehicle.toJson()],
        };

        // Save Seeker profile to Firebase Realtime Database
        await FirebaseRtdbService.updateUserProfile(uid, profilePayload);

        // Also save directly to user vehicles node
        await FirebaseRtdbService.addUserVehicle(uid, vehicle);

        // Update Riverpod State
        ref.read(currentRoleProvider.notifier).state = 'user';
        ref.read(userProfileProvider.notifier).state = UserProfile(
          uid: uid,
          name: name,
          email: email,
          phone: phone,
          photoUrl: user?.photoURL ?? '',
          role: 'user',
          walletBalance: 0.0,
          fcmToken: '',
          vehicles: [vehicle],
          createdAt: DateTime.now(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome to Mee Parking! Profile setup complete.'),
              backgroundColor: AppColors.greenSuccess,
            ),
          );

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        final businessName = _businessNameCtrl.text.trim();
        final city = _cityCtrl.text.trim();
        final capacity = int.tryParse(_capacityCtrl.text.trim()) ?? 5;

        final partnerPayload = {
          'uid': uid,
          'name': name,
          'email': email,
          'phone': phone,
          'role': 'partner',
          'businessName': businessName,
          'city': city,
          'capacity': capacity,
          'photoUrl': user?.photoURL ?? '',
          'walletBalance': 0.0,
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Save Partner profile to Firebase Realtime Database
        await FirebaseRtdbService.updateUserProfile(uid, partnerPayload);

        // Update Riverpod State
        ref.read(currentRoleProvider.notifier).state = 'partner';
        ref.read(userProfileProvider.notifier).state = UserProfile(
          uid: uid,
          name: name,
          email: email,
          phone: phone,
          photoUrl: user?.photoURL ?? '',
          role: 'partner',
          walletBalance: 0.0,
          fcmToken: '',
          vehicles: [],
          createdAt: DateTime.now(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Partner account registered! Let\'s list your space.'),
              backgroundColor: AppColors.greenSuccess,
            ),
          );

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const PartnerOnboardingWizard(isAddingListingOnly: false),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildVehicleChip(String type, IconData icon, String subtitle) {
    final isSelected = _selectedVehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedVehicleType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.08) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                type,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSeeker = widget.role == 'user';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top Right Ambient Gradient Orb
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.12),
                    const Color(0xFF6B2D9B).withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Bottom Left Ambient Gradient Orb
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B3DCC).withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo Header
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/mee_parking_logo.png',
                            width: 65,
                            height: 65,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_parking_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Image.asset(
                            'assets/mee_parking_text_logo.png',
                            width: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text(
                              'Mee Parking',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isSeeker ? 'Seeker Profile Setup' : 'Partner Profile Setup',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Form Container Card
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name Input
                          const Text(
                            'Full Name *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: isSeeker ? 'e.g. Rohan Sharma' : 'e.g. Rajesh Kumar',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary, size: 18),
                              fillColor: const Color(0xFFF9FAFB),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Phone Number Input
                          Text(
                            isSeeker ? 'Phone Number (Optional)' : 'Phone Number *',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '+91 98765 43210',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 18),
                              fillColor: const Color(0xFFF9FAFB),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Seeker Specific: Vehicle Type & Model
                          if (isSeeker) ...[
                            const Text(
                              'Primary Vehicle Type *',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildVehicleChip('2-Wheeler', Icons.two_wheeler_outlined, 'Bike / Scooter'),
                                const SizedBox(width: 6),
                                _buildVehicleChip('3-Wheeler', Icons.electric_rickshaw_outlined, 'Auto / E-Rick'),
                                const SizedBox(width: 6),
                                _buildVehicleChip('4-Wheeler', Icons.directions_car_outlined, 'Car / SUV'),
                              ],
                            ),
                            const SizedBox(height: 10),

                            const Text(
                              'Vehicle Make & Model *',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _vehicleModelCtrl,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: _selectedVehicleType == '2-Wheeler'
                                    ? 'e.g. Honda Activa 6G / Ather 450X'
                                    : _selectedVehicleType == '3-Wheeler'
                                        ? 'e.g. Mahindra Treo'
                                        : 'e.g. Hyundai Creta / Tata Nexon EV',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                prefixIcon: const Icon(Icons.commute_outlined, color: AppColors.primary, size: 18),
                                fillColor: const Color(0xFFF9FAFB),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            const Text(
                              'Vehicle Reg. Number (Optional)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _vehicleNumberCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'e.g. KA 01 AB 1234',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.primary, size: 18),
                                fillColor: const Color(0xFFF9FAFB),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                                ),
                              ),
                            ),
                          ],

                          // Partner Specific: Space / Business Details
                          if (!isSeeker) ...[
                            const Text(
                              'Property / Space Name *',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _businessNameCtrl,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'e.g. Green Valley Parking Lot',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                prefixIcon: const Icon(Icons.domain_outlined, color: AppColors.primary, size: 18),
                                fillColor: const Color(0xFFF9FAFB),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            const Text(
                              'City / Area *',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _cityCtrl,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'e.g. South Extension, New Delhi',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                prefixIcon: const Icon(Icons.location_city_outlined, color: AppColors.primary, size: 18),
                                fillColor: const Color(0xFFF9FAFB),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Primary Gradient Submit Button
                          Container(
                            width: double.infinity,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSaveAndProceed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                    )
                                  : Text(
                                      isSeeker
                                          ? 'Complete Profile & Start Parking'
                                          : 'Save & Continue to Space Setup',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Back Link
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Back to Role Selection',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
