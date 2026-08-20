import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../core/services/parking_service.dart';
import '../../core/services/razorpay_service.dart';

import '../../shared/models/booking.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/offer.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/slot_space_slider.dart';
import '../booking/booking_confirmed_screen.dart';


class ParkingDetailsScreen extends ConsumerStatefulWidget {
  final String spaceId;

  const ParkingDetailsScreen({super.key, required this.spaceId});

  @override
  ConsumerState<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends ConsumerState<ParkingDetailsScreen> {
  final RazorpayService _razorpayService = RazorpayService();
  Booking? _pendingRazorpayBooking;
  double _pendingWalletDeduct = 0.0;
  ParkingSpace? _space;
  bool _isLoading = true;
  bool _isSaved = false;
  double? _userLat;
  double? _userLng;

  void _showTopToast({
    required BuildContext context,
    required String message,
    required bool isSuccess,
  }) {
    final mediaQuery = MediaQuery.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isSuccess ? AppColors.greenSuccess : AppColors.redError,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - 130,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSpaceDetails();
    _fetchUserLocation();

    _razorpayService.init(
      onSuccess: (res) async {
        final booking = _pendingRazorpayBooking;
        final deduct = _pendingWalletDeduct;
        _pendingRazorpayBooking = null;
        _pendingWalletDeduct = 0.0;

        if (booking != null) {
          final finalizedBooking = booking.copyWith(paymentId: res.paymentId);
          try {
            await FirebaseRtdbService.createBooking(finalizedBooking);
            if (deduct > 0) {
              await FirebaseRtdbService.deductWallet(booking.userId, deduct, spaceTitle: booking.spaceTitle);
            }
          } catch (e) {
            debugPrint('Error saving booking after Razorpay payment: $e');
          }

          if (mounted) {
            _showTopToast(
              context: context,
              message: '🎉 Booking Confirmed! Spot reserved for ${booking.spaceTitle}',
              isSuccess: true,
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BookingConfirmedScreen(booking: finalizedBooking),
              ),
            );
          }
        }
      },
      onFailure: (res) {
        _pendingRazorpayBooking = null;
        _pendingWalletDeduct = 0.0;
        if (mounted) {
          _showTopToast(
            context: context,
            message: 'Payment Cancelled / Failed: ${res.message ?? "Transaction was not completed"}',
            isSuccess: false,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
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

  String _distanceLabel(double spaceLat, double spaceLng) {
    if (_userLat == null || _userLng == null) return '';
    const R = 6371.0;
    final dLat = (spaceLat - _userLat!) * math.pi / 180;
    final dLng = (spaceLng - _userLng!) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_userLat! * math.pi / 180) * math.cos(spaceLat * math.pi / 180) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final dist = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    if (dist < 1) return '${(dist * 1000).round()} m';
    return '${dist.toStringAsFixed(1)} km';
  }

  Future<void> _loadSpaceDetails() async {
    final space = await ParkingService.getSpaceById(widget.spaceId);
    final user = ref.read(userProfileProvider);
    final isSaved = await FirebaseRtdbService.isSpotSaved(user.uid, widget.spaceId);
    if (mounted) {
      setState(() {
        _space = space;
        _isSaved = isSaved;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _space == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final space = _space!;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery Header with Overlay Buttons
            Stack(
              children: [
                SlotSpaceSlider(
                  images: space.images,
                  height: 260,
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: Icon(
                              _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: _isSaved ? Colors.red : AppColors.primary,
                            ),
                            onPressed: () async {
                              final user = ref.read(userProfileProvider);
                              final messenger = ScaffoldMessenger.of(context);
                              final newSaved = await FirebaseRtdbService.toggleSavedSpot(user.uid, widget.spaceId);
                              if (mounted) {
                                setState(() => _isSaved = newSaved);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(newSaved ? 'Saved to Favourites ❤️' : 'Removed from Favourites'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Space Details Content
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    space.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          space.address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${space.rating}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${space.reviewCount} reviews)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      if (_distanceLabel(space.lat, space.lng).isNotEmpty) ...[
                        const Icon(Icons.navigation, color: AppColors.textSecondaryLight, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _distanceLabel(space.lat, space.lng),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Owner Contact Card (Chat & Audio Call)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFF3E8FF),
                          child: Icon(Icons.person, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Partner Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Space Owner • Verified', style: TextStyle(fontSize: 11, color: AppColors.greenSuccess)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),                  // Amenities Chips - 2 per row grid
                  const Text(
                    'Amenities',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final cleanAmenities = space.amenities
                          .map((a) => ParkingSpace.sanitizeAmenity(a))
                          .where((a) => a.isNotEmpty)
                          .toSet()
                          .toList();

                      IconData iconFor(String label) {
                        final lower = label.toLowerCase();
                        if (lower.contains('cctv')) return Icons.videocam_outlined;
                        if (lower.contains('ev') || lower.contains('charger') || lower.contains('charging')) return Icons.ev_station;
                        if (lower.contains('covered') || lower.contains('roof')) return Icons.roofing;
                        if (lower.contains('security') || lower.contains('guard')) return Icons.security;
                        if (lower.contains('valet')) return Icons.directions_car_outlined;
                        if (lower.contains('boom') || lower.contains('barrier') || lower.contains('gate')) return Icons.sensor_door_outlined;
                        if (lower.contains('restroom') || lower.contains('washroom')) return Icons.wc_outlined;
                        if (lower.contains('wheelchair') || lower.contains('accessible')) return Icons.accessible_outlined;
                        if (lower.contains('inflat') || lower.contains('air')) return Icons.tire_repair;
                        if (lower.contains('flood') || lower.contains('light')) return Icons.light_outlined;
                        if (lower.contains('emergency')) return Icons.emergency_outlined;
                        if (lower.contains('automated')) return Icons.settings_remote_outlined;
                        if (lower.contains('wash')) return Icons.local_car_wash_outlined;
                        return Icons.check_circle_outline;
                      }

                      final rows = <Widget>[];
                      for (int i = 0; i < cleanAmenities.length; i += 2) {
                        final left = cleanAmenities[i];
                        final right = i + 1 < cleanAmenities.length ? cleanAmenities[i + 1] : null;
                        rows.add(
                          Row(
                            children: [
                              Expanded(
                                child: _buildAmenityTile(left, iconFor(left)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: right != null
                                    ? _buildAmenityTile(right, iconFor(right))
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        );
                        rows.add(const SizedBox(height: 10));
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rows,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    space.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),

      // Fixed Bottom CTA Bar: Selected Price & "Book Spot Now" Button
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Starts from',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  Text(
                    '₹${space.pricing.twoWheeler.hourly.toInt()} / hr',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _showBookingOptionsBottomSheet(context, space),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Book Spot Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingOptionsBottomSheet(BuildContext context, ParkingSpace space) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int selectedVehicleIdx = 0;
        String selectedBookingType = 'Hourly';
        int selectedTimeSlotIdx = 1;
        int hourlyDuration = 2;

        DateTimeRange dailyDateRange = DateTimeRange(
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(days: 2)),
        );

        DateTime passStartDate = DateTime.now();

        final List<String> timeSlots = [
          '08:00 AM',
          '09:00 AM',
          '10:00 AM',
          '11:00 AM',
          '12:00 PM',
          '01:00 PM',
          '02:00 PM',
          '03:00 PM',
          '04:00 PM',
          '05:00 PM',
        ];

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Consumer(
              builder: (context, ref, _) {
                final user = ref.watch(userProfileProvider);
                final vehiclesAsync = ref.watch(userVehiclesStreamProvider);
                final List<Vehicle> streamedVehicles = vehiclesAsync.asData?.value ?? [];
                final List<Vehicle> userVehicles = streamedVehicles.isNotEmpty
                    ? streamedVehicles
                    : user.vehicles;

                if (userVehicles.isNotEmpty && selectedVehicleIdx >= userVehicles.length) {
                  selectedVehicleIdx = 0;
                }

                final Vehicle? selectedVehicle = userVehicles.isNotEmpty ? userVehicles[selectedVehicleIdx] : null;
                final String selectedVehicleCategory = selectedVehicle != null ? selectedVehicle.category : '4-Wheeler';
                final String selectedVehicleReg = selectedVehicle?.number ?? 'Vehicle not selected';
                final String selectedVehicleModel = selectedVehicle?.model ?? 'Vehicle';

                VehicleCategoryRates rates;
                if (selectedVehicleCategory == '2-Wheeler') {
                  rates = space.pricing.twoWheeler;
                } else if (selectedVehicleCategory == '3-Wheeler') {
                  rates = space.pricing.threeWheeler;
                } else {
                  rates = space.pricing.fourWheeler;
                }

                double totalCalculated;

                if (selectedBookingType == 'Hourly') {
                  totalCalculated = rates.hourly * hourlyDuration;
                } else if (selectedBookingType == 'Daily') {
                  final days = dailyDateRange.duration.inDays > 0
                      ? dailyDateRange.duration.inDays
                      : 1;
                  totalCalculated = rates.daily * days;
                } else if (selectedBookingType == 'Weekly') {
                  totalCalculated = rates.weekly;
                } else {
                  totalCalculated = rates.monthly;
                }

                final int passDays = selectedBookingType == 'Weekly' ? 7 : 30;
                final DateTime passEndDate = passStartDate.add(Duration(days: passDays));

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.90,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Indicator
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Vehicle & Booking Type',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    space.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // 1. User Added Vehicles List (ONLY user added vehicles displayed!)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '1. Select Your Vehicle',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showAddQuickVehicleSheet(context, user.uid),
                              child: const Row(
                                children: [
                                  Icon(Icons.add_circle_outline, size: 15, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add Vehicle',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (userVehicles.isEmpty)
                          GestureDetector(
                            onTap: () => _showAddQuickVehicleSheet(context, user.uid),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'No vehicles added yet • Tap to Add Vehicle',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 72,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: userVehicles.length + 1,
                              itemBuilder: (context, idx) {
                                if (idx == userVehicles.length) {
                                  return GestureDetector(
                                    onTap: () => _showAddQuickVehicleSheet(context, user.uid),
                                    child: Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundLight,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add, color: AppColors.primary, size: 22),
                                          SizedBox(height: 2),
                                          Text(
                                            'Add New',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final veh = userVehicles[idx];
                                final isSelected = selectedVehicleIdx == idx;
                                final cat = veh.category;
                                final IconData vehIcon = cat == '2-Wheeler'
                                    ? Icons.two_wheeler
                                    : cat == '3-Wheeler'
                                        ? Icons.electric_rickshaw
                                        : Icons.directions_car;

                                return GestureDetector(
                                  onTap: () => setSheetState(() => selectedVehicleIdx = idx),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 200,
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary.withOpacity(0.06) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withOpacity(0.15),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.primary : Colors.purple.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            vehIcon,
                                            color: isSelected ? Colors.white : AppColors.primary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                veh.model,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      veh.number,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textSecondaryLight,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      cat == '2-Wheeler'
                                                          ? '2W'
                                                          : cat == '3-Wheeler'
                                                              ? '3W'
                                                              : '4W',
                                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),

                        // 2. Booking Type Selection
                    const Text(
                      '2. Select Type of Booking',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBookingTypeCard(
                          title: 'Hourly',
                          priceText: '₹${rates.hourly.toInt()} / hr',
                          icon: Icons.access_time_filled,
                          isSelected: selectedBookingType == 'Hourly',
                          onTap: () {
                            setSheetState(() => selectedBookingType = 'Hourly');
                          },
                        ),
                        _buildBookingTypeCard(
                          title: 'Daily',
                          priceText: '₹${rates.daily.toInt()} / day',
                          icon: Icons.wb_sunny_rounded,
                          isSelected: selectedBookingType == 'Daily',
                          onTap: () {
                            setSheetState(() => selectedBookingType = 'Daily');
                          },
                        ),
                        _buildBookingTypeCard(
                          title: 'Weekly Pass',
                          priceText: '₹${rates.weekly.toInt()} / wk',
                          icon: Icons.date_range_rounded,
                          badge: 'Save 20%',
                          isSelected: selectedBookingType == 'Weekly',
                          onTap: () {
                            setSheetState(() => selectedBookingType = 'Weekly');
                          },
                        ),
                        _buildBookingTypeCard(
                          title: 'Monthly Pass',
                          priceText: '₹${rates.monthly.toInt()} / mo',
                          icon: Icons.calendar_month_rounded,
                          badge: 'Best Value',
                          isSelected: selectedBookingType == 'Monthly',
                          onTap: () {
                            setSheetState(() => selectedBookingType = 'Monthly');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3. Hourly Booking Time Slot Selector
                    if (selectedBookingType == 'Hourly') ...[
                      const Text(
                        'Select Start Time Slot',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: timeSlots.length,
                          itemBuilder: (context, index) {
                            final slot = timeSlots[index];
                            final isSelected = selectedTimeSlotIdx == index;
                            return GestureDetector(
                              onTap: () => setSheetState(() => selectedTimeSlotIdx = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    slot,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Duration (Hours)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Time: ${timeSlots[selectedTimeSlotIdx]} ($hourlyDuration hrs)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: hourlyDuration > 1
                                      ? () => setSheetState(() => hourlyDuration--)
                                      : null,
                                ),
                                Text(
                                  '$hourlyDuration hrs',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: hourlyDuration < 24
                                      ? () => setSheetState(() => hourlyDuration++)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 4. Daily Booking Continuous Dates Picker
                    if (selectedBookingType == 'Daily') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.date_range, color: AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Continuous Days (${dailyDateRange.duration.inDays > 0 ? dailyDateRange.duration.inDays : 1} Days)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final pickedRange = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 90)),
                                      initialDateRange: dailyDateRange,
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.light(
                                              primary: AppColors.primary,
                                              onPrimary: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (pickedRange != null) {
                                      setSheetState(() => dailyDateRange = pickedRange);
                                    }
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit_calendar, size: 14, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Select Range',
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Start Date',
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDateString(dailyDateRange.start),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'End Date',
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDateString(dailyDateRange.end),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 5. Start and End Date Display (Weekly / Monthly Pass)
                    if (selectedBookingType == 'Weekly' || selectedBookingType == 'Monthly') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.verified_outlined, color: AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${selectedBookingType == 'Weekly' ? '7-Day' : '30-Day'} Pass Validity',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: passStartDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 90)),
                                    );
                                    if (picked != null) {
                                      setSheetState(() => passStartDate = picked);
                                    }
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit_calendar, size: 14, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Change',
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Start Date',
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDateString(passStartDate),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'End Date',
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDateString(passEndDate),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Summary & Proceed Action Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$selectedVehicleCategory • $selectedBookingType',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total: ₹${totalCalculated.toInt()}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              final String dateText;
                              final String timeText;

                              if (selectedBookingType == 'Hourly') {
                                dateText = _formatDateString(DateTime.now());
                                timeText = '${timeSlots[selectedTimeSlotIdx]} ($hourlyDuration hrs)';
                              } else if (selectedBookingType == 'Daily') {
                                dateText = '${_formatDateString(dailyDateRange.start)} - ${_formatDateString(dailyDateRange.end)}';
                                timeText = 'Daily Pass (${dailyDateRange.duration.inDays > 0 ? dailyDateRange.duration.inDays : 1} Days)';
                              } else if (selectedBookingType == 'Weekly') {
                                dateText = '${_formatDateString(passStartDate)} - ${_formatDateString(passEndDate)}';
                                timeText = 'Weekly Pass (7 Days)';
                              } else {
                                dateText = '${_formatDateString(passStartDate)} - ${_formatDateString(passEndDate)}';
                                timeText = 'Monthly Pass (30 Days)';
                              }

                              Navigator.of(context).pop();
                              _showInstantBookingSheet(
                                context: context,
                                space: space,
                                vehicleCategory: selectedVehicleCategory,
                                vehicleNumber: selectedVehicleReg,
                                vehicleModel: selectedVehicleModel,
                                bookingType: selectedBookingType,
                                totalAmount: totalCalculated,
                                bookingDateText: dateText,
                                timeSlotText: timeText,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'Proceed to Pay',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  },
);
}

  void _showInstantBookingSheet({
    required BuildContext context,
    required ParkingSpace space,
    required String bookingType,
    required String vehicleCategory,
    required String vehicleNumber,
    required String vehicleModel,
    required double totalAmount,
    required String bookingDateText,
    required String timeSlotText,
  }) {
    bool isProcessing = false;
    final couponController = TextEditingController();
    Offer? selectedOffer;
    String? couponStatusMessage;
    bool isCouponSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setPayState) {
            final user = ref.watch(userProfileProvider);
            final walletAsync = ref.watch(walletBalanceStreamProvider);
            final rawBalance = walletAsync.asData?.value ?? 1250.0;
            final double walletBalance = rawBalance > 0 ? rawBalance : 0.0;

            final offersAsync = ref.watch(offersStreamProvider);
            final allOffers = offersAsync.asData?.value ?? [];

            final double discount = selectedOffer != null ? selectedOffer!.calculateDiscount(totalAmount) : 0.0;
            final double payableTotal = (totalAmount - discount).clamp(0.0, double.infinity);
            final bool hasEnoughWallet = walletBalance >= payableTotal;

            final String vehicleNo = vehicleNumber;
            final String vehicleMdl = vehicleModel;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.90,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.assignment_outlined, color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Checkout Summary',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      const Text(
                        '1. Parking Space Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.local_parking, color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        space.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${space.address}, ${space.city}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${space.rating}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '2. Vehicle Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                vehicleCategory.contains('2')
                                    ? Icons.two_wheeler
                                    : vehicleCategory.contains('3')
                                        ? Icons.electric_rickshaw
                                        : Icons.directions_car,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$vehicleCategory ($vehicleMdl)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Reg No: $vehicleNo',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '3. User Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary.withOpacity(0.12),
                              child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name.isNotEmpty ? user.name : 'Rohan Sharma',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${user.phone.isNotEmpty ? user.phone : "+91 9876543210"} • ${user.email.isNotEmpty ? user.email : "rohan@example.com"}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Offers & Promo Code',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                          if (selectedOffer != null)
                            GestureDetector(
                              onTap: () {
                                setPayState(() {
                                  selectedOffer = null;
                                  couponController.clear();
                                  couponStatusMessage = null;
                                  isCouponSuccess = false;
                                });
                              },
                              child: const Text(
                                'Remove',
                                style: TextStyle(
                                  color: AppColors.redError,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selectedOffer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '🎉 "${selectedOffer!.code}" Applied! Saving ₹${discount.toInt()}',
                                  style: const TextStyle(
                                    color: Color(0xFF065F46),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: TextField(
                                  controller: couponController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: 'Enter coupon code',
                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    filled: true,
                                    fillColor: AppColors.backgroundLight,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppColors.primary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                onPressed: () {
                                  final entered = couponController.text.trim().toUpperCase();
                                  if (entered.isEmpty) return;

                                  final matched = allOffers.cast<Offer?>().firstWhere(
                                        (o) => o?.code == entered && o?.isActive == true,
                                        orElse: () => null,
                                      );

                                  if (matched == null) {
                                    setPayState(() {
                                      couponStatusMessage = 'Invalid or expired coupon "$entered"';
                                      isCouponSuccess = false;
                                    });
                                  } else if (totalAmount < matched.minBookingAmount) {
                                    setPayState(() {
                                      couponStatusMessage =
                                          'Min booking spend ₹${matched.minBookingAmount.toInt()} required for this coupon.';
                                      isCouponSuccess = false;
                                    });
                                  } else {
                                    setPayState(() {
                                      selectedOffer = matched;
                                      couponStatusMessage = null;
                                      isCouponSuccess = true;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Apply',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (couponStatusMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            couponStatusMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isCouponSuccess ? const Color(0xFF10B981) : AppColors.redError,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (allOffers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: allOffers.take(4).map((offer) {
                                return GestureDetector(
                                  onTap: () {
                                    if (totalAmount < offer.minBookingAmount) {
                                      setPayState(() {
                                        couponStatusMessage =
                                            'Min spend ₹${offer.minBookingAmount.toInt()} required for ${offer.code}';
                                        isCouponSuccess = false;
                                      });
                                    } else {
                                      setPayState(() {
                                        selectedOffer = offer;
                                        couponController.text = offer.code;
                                        couponStatusMessage = null;
                                        isCouponSuccess = true;
                                      });
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.purple.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.local_offer, size: 12, color: Colors.purple),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${offer.code} (${offer.discountType == 'percentage' ? '${offer.discountValue.toInt()}% OFF' : '₹${offer.discountValue.toInt()} OFF'})',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        '4. Booking & Amount Summary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Plan: $bookingType',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  bookingDateText,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Time Slot / Validity',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                                Text(
                                  timeSlotText,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            if (discount > 0) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Base Rate',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                  ),
                                  Text(
                                    '₹${totalAmount.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.local_offer, size: 14, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Coupon (${selectedOffer!.code})',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '- ₹${discount.toInt()}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet, size: 16, color: AppColors.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      'Wallet Balance',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹${walletBalance.toInt()}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  hasEnoughWallet ? 'Auto-Deduction' : 'Partial Wallet Deduct',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: hasEnoughWallet ? AppColors.greenSuccess : AppColors.orangeWarning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  hasEnoughWallet
                                      ? '- ₹${payableTotal.toInt()}'
                                      : '- ₹${walletBalance.toInt()} (+ ₹${(payableTotal - walletBalance).toInt()} Razorpay)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Payable',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                                ),
                                Text(
                                  '₹${payableTotal.toInt()}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  setPayState(() => isProcessing = true);
                                  final userId = user.uid.isNotEmpty ? user.uid : 'user_01';
                                  final booking = Booking(
                                    id: 'MEE${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                                    spaceId: space.id,
                                    spaceTitle: space.title,
                                    spaceAddress: space.address,
                                    userId: userId,
                                    partnerId: space.ownerId,
                                    vehicleNumber: vehicleNo,
                                    vehicleModel: vehicleMdl,
                                    vehicleType: vehicleCategory,
                                    bookingDate: bookingDateText,
                                    timeSlot: timeSlotText,
                                    totalAmount: payableTotal,
                                    couponCode: selectedOffer?.code,
                                    discountAmount: discount > 0 ? discount : null,
                                    status: 'upcoming',
                                    createdAt: DateTime.now().toIso8601String(),
                                  );

                                  final hasConflict = await FirebaseRtdbService.hasVehicleBookingConflict(
                                    vehicleNumber: vehicleNo,
                                    spaceId: space.id,
                                    bookingDate: bookingDateText,
                                    timeSlot: timeSlotText,
                                  );

                                  if (hasConflict) {
                                    setPayState(() => isProcessing = false);
                                    if (context.mounted) {
                                      _showTopToast(
                                        context: context,
                                        message: 'Booking Failed: Vehicle ($vehicleNo) is already booked for $timeSlotText on $bookingDateText.',
                                        isSuccess: false,
                                      );
                                    }
                                    return;
                                  }

                                  if (hasEnoughWallet) {
                                    try {
                                      await FirebaseRtdbService.createBooking(booking);
                                      await FirebaseRtdbService.deductWallet(userId, payableTotal, spaceTitle: space.title);
                                    } catch (e) {
                                      debugPrint('Booking save error: $e');
                                      setPayState(() => isProcessing = false);
                                      if (context.mounted) {
                                        _showTopToast(
                                          context: context,
                                          message: 'Booking failed. Please check connection and try again.',
                                          isSuccess: false,
                                        );
                                      }
                                      return;
                                    }

                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                    if (context.mounted) {
                                      _showTopToast(
                                        context: context,
                                        message: '🎉 Booking Confirmed! Spot reserved for ${booking.spaceTitle}',
                                        isSuccess: true,
                                      );
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => BookingConfirmedScreen(booking: booking),
                                        ),
                                      );
                                    }
                                  } else {
                                    final double payableViaRazorpay = walletBalance > 0 ? (payableTotal - walletBalance) : payableTotal;
                                    final double walletDeduct = walletBalance > 0 ? walletBalance : 0.0;

                                    _pendingRazorpayBooking = booking;
                                    _pendingWalletDeduct = walletDeduct;

                                    if (ctx.mounted) Navigator.of(ctx).pop();

                                    await _razorpayService.openCheckout(
                                      amount: payableViaRazorpay,
                                      name: 'Mee Parking',
                                      description: 'Reservation for ${space.title}',
                                      email: user.email.isNotEmpty ? user.email : 'user@meeparking.com',
                                      contact: user.phone.isNotEmpty ? user.phone : '9876543210',
                                      customerName: user.name.isNotEmpty ? user.name : 'Customer',
                                      customerId: userId,
                                      notes: {
                                        'bookingId': booking.id,
                                        'spaceId': space.id,
                                        'spaceTitle': space.title,
                                        'vehicleNumber': vehicleNo,
                                        'vehicleModel': vehicleMdl,
                                        'vehicleType': vehicleCategory,
                                        'userId': userId,
                                        'userName': user.name,
                                        'userPhone': user.phone,
                                        'userEmail': user.email,
                                        'totalAmount': payableTotal.toString(),
                                        'couponCode': selectedOffer?.code ?? '',
                                      },
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Pay ₹${payableTotal.toInt()} & Confirm Booking',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateString(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }



  Widget _buildBookingTypeCard({
    required String title,
    required String priceText,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 155,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 155,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? AppColors.primary : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    priceText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
            // Green Badge Tag positioned at top right corner
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.greenSuccess,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddQuickVehicleSheet(BuildContext context, String userId) {
    final typeCtrl = TextEditingController(text: '4-Wheeler');
    final modelCtrl = TextEditingController();
    final regNoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setQuickState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Vehicle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: typeCtrl.text,
                  decoration: const InputDecoration(labelText: 'Vehicle Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '4-Wheeler', child: Text('4-Wheeler (Car / SUV)')),
                    DropdownMenuItem(value: '2-Wheeler', child: Text('2-Wheeler (Bike / Scooter)')),
                    DropdownMenuItem(value: '3-Wheeler', child: Text('3-Wheeler (Auto / Rickshaw)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setQuickState(() => typeCtrl.text = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: 'Make & Model (e.g. Hyundai Creta)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: regNoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Registration No (e.g. HR 26 CQ 9999)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (modelCtrl.text.trim().isNotEmpty && regNoCtrl.text.trim().isNotEmpty) {
                        final newVeh = Vehicle(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          number: regNoCtrl.text.trim().toUpperCase(),
                          model: modelCtrl.text.trim(),
                          type: typeCtrl.text,
                        );
                        await FirebaseRtdbService.addUserVehicle(userId, newVeh);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Save & Select Vehicle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmenityTile(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
