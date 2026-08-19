import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_providers.dart';
import 'booking_confirmed_screen.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final ParkingSpace space;
  final String vehicleType;
  final String bookingType;
  final double initialAmount;
  final int durationUnits;

  const BookingScreen({
    super.key,
    required this.space,
    this.vehicleType = '4-Wheeler',
    this.bookingType = 'Hourly',
    this.initialAmount = 60.0,
    this.durationUnits = 1,
  });

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  int _selectedDateIdx = 0;
  int _selectedTimeIdx = 1; // 09:00 AM
  int _selectedVehicleIdx = 0;

  final List<Map<String, String>> _dates = [
    {'day': 'Mon', 'date': '20 May'},
    {'day': 'Tue', 'date': '21 May'},
    {'day': 'Wed', 'date': '22 May'},
    {'day': 'Thu', 'date': '23 May'},
  ];

  final List<String> _timeSlots = [
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
  ];

  bool _isProcessing = false;

  void _showChangeVehicleDialog(List<Vehicle> vehicles) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Vehicle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...List.generate(vehicles.length, (index) {
              final v = vehicles[index];
              final isSelected = _selectedVehicleIdx == index;
              return ListTile(
                leading: Icon(
                  v.type == 'car' ? Icons.directions_car : Icons.two_wheeler,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                title: Text(v.number, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(v.model),
                trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _selectedVehicleIdx = index);
                  Navigator.of(ctx).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _processPayment() async {
    setState(() => _isProcessing = true);
    final user = ref.read(userProfileProvider);
    final vehicle = user.vehicles.isNotEmpty
        ? user.vehicles[_selectedVehicleIdx.clamp(0, user.vehicles.length - 1)]
        : Vehicle(
            id: 'v1',
            number: 'DL 01 AB 1234',
            model: 'Honda City',
            type: widget.vehicleType.contains('2') ? 'bike' : 'car',
          );

    final totalAmt = widget.initialAmount > 0
        ? widget.initialAmount
        : widget.space.pricing.hourly;

    final booking = Booking(
      id: 'MEE${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      spaceId: widget.space.id,
      spaceTitle: widget.space.title,
      spaceAddress: widget.space.address,
      userId: user.uid.isNotEmpty ? user.uid : 'user_01',
      partnerId: widget.space.ownerId,
      vehicleNumber: vehicle.number,
      vehicleType: widget.vehicleType,
      bookingDate: '${_dates[_selectedDateIdx]['day']} ${_dates[_selectedDateIdx]['date']} 2026',
      timeSlot: '${_timeSlots[_selectedTimeIdx]} (${widget.bookingType})',
      totalAmount: totalAmt,
      status: 'upcoming',
      createdAt: DateTime.now().toIso8601String(),
    );

    // Save to Live Firebase Realtime DB
    await FirebaseRtdbService.createBooking(booking);

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingConfirmedScreen(booking: booking),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);
    final vehicles = user.vehicles;
    final selectedVehicle = vehicles.isNotEmpty
        ? vehicles[_selectedVehicleIdx.clamp(0, vehicles.length - 1)]
        : Vehicle(
            id: 'v1',
            number: 'DL 01 AB 1234',
            model: 'Honda City',
            type: widget.vehicleType.contains('2') ? 'bike' : 'car',
          );

    final double totalAmt = widget.initialAmount > 0
        ? widget.initialAmount
        : widget.space.pricing.hourly;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Select Date & Time',
          style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking Summary Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.vehicleType} • ${widget.bookingType} Plan (${widget.durationUnits} ${widget.bookingType == 'Hourly' ? 'hrs' : 'units'})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date Selector Row
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dates.length,
                  itemBuilder: (context, index) {
                    final d = _dates[index];
                    final isSelected = _selectedDateIdx == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDateIdx = index),
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              d['day']!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white70 : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d['date']!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Select Time Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${totalAmt.toInt()} Total',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final timeStr = _timeSlots[index];
                  final isSelected = _selectedTimeIdx == index;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedTimeIdx = index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Vehicle Details Card
              const Text(
                'Vehicle Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3E8FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.vehicleType.contains('2') ? Icons.two_wheeler : Icons.directions_car,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedVehicle.number,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${selectedVehicle.model} (${widget.vehicleType})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showChangeVehicleDialog(vehicles),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Total Amount & Payment CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        '₹${totalAmt.toInt()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const Text(
                        'Includes all taxes',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 180,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Continue to Payment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

