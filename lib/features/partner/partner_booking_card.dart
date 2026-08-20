import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/booking.dart';
import '../chat/call_screen.dart';
import '../chat/chat_screen.dart';

class PartnerBookingCard extends StatefulWidget {
  final Booking booking;
  final bool isCompact;

  const PartnerBookingCard({
    super.key,
    required this.booking,
    this.isCompact = false,
  });

  @override
  State<PartnerBookingCard> createState() => _PartnerBookingCardState();
}

class _PartnerBookingCardState extends State<PartnerBookingCard> {
  String _customerName = '';
  String _customerPhone = '';
  String _customerPhoto = '';
  String _vehicleDisplay = '';

  @override
  void initState() {
    super.initState();
    _initDefaults();
    _fetchCustomerProfile();
  }

  @override
  void didUpdateWidget(covariant PartnerBookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.id != widget.booking.id ||
        oldWidget.booking.userId != widget.booking.userId) {
      _initDefaults();
      _fetchCustomerProfile();
    }
  }

  void _initDefaults() {
    final b = widget.booking;
    final vehNum = b.vehicleNumber.trim();
    final vehModel = b.vehicleModel.trim();
    final vehType = b.vehicleType.trim();

    if (vehNum.isNotEmpty && vehNum != 'DL 01 AB 1234' && !vehNum.startsWith('-')) {
      _customerName = 'Customer ($vehNum)';
      _vehicleDisplay = vehModel.isNotEmpty ? '$vehNum • $vehModel' : vehNum;
    } else if (vehModel.isNotEmpty && vehModel != 'Honda City') {
      _customerName = 'Customer ($vehModel)';
      _vehicleDisplay = vehModel;
    } else {
      _customerName = 'Customer';
      _vehicleDisplay = vehType.isNotEmpty ? vehType.toUpperCase() : 'Vehicle';
    }

    if (vehType.isNotEmpty && !_vehicleDisplay.toUpperCase().contains(vehType.toUpperCase())) {
      _vehicleDisplay = '$_vehicleDisplay (${vehType.toUpperCase()})';
    }
  }

  Future<void> _fetchCustomerProfile() async {
    final uid = widget.booking.userId.trim();
    if (uid.isEmpty) return;

    try {
      final profile = await FirebaseRtdbService.getUserProfile(uid);
      if (profile != null && mounted) {
        setState(() {
          final pName = (profile['name'] ?? '').toString().trim();
          if (pName.isNotEmpty) {
            _customerName = pName;
          }
          final pPhone = (profile['phone'] ?? '').toString().trim();
          if (pPhone.isNotEmpty) {
            _customerPhone = pPhone;
          }
          final pPhoto = (profile['photoUrl'] ?? '').toString().trim();
          if (pPhoto.isNotEmpty) {
            _customerPhoto = pPhoto;
          }

          // If booking vehicle number was empty or generic, check profile registered vehicles
          if ((widget.booking.vehicleNumber.isEmpty || widget.booking.vehicleNumber == 'DL 01 AB 1234') &&
              profile['vehicles'] is List &&
              (profile['vehicles'] as List).isNotEmpty) {
            final firstVeh = (profile['vehicles'] as List).first;
            if (firstVeh is Map) {
              final vNum = (firstVeh['number'] ?? '').toString().trim();
              final vMod = (firstVeh['model'] ?? '').toString().trim();
              if (vNum.isNotEmpty) {
                _vehicleDisplay = vMod.isNotEmpty ? '$vNum • $vMod' : vNum;
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  String _formatBookingId(String id) {
    if (id.isEmpty) return 'Booking';
    if (id.startsWith('-')) {
      final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (clean.length >= 6) {
        return 'ID: #${clean.substring(clean.length - 6).toUpperCase()}';
      }
      return 'ID: #${clean.toUpperCase()}';
    }
    return id.startsWith('MEE') ? id : 'ID: #$id';
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final isCompleted = booking.computedStatus == 'completed';

    Color statusColor = AppColors.greenSuccess;
    if (isCompleted) statusColor = const Color(0xFF2563EB);
    if (booking.computedStatus == 'cancelled') statusColor = AppColors.redError;

    final initial = _customerName.isNotEmpty && !_customerName.startsWith('Customer')
        ? _customerName.trim().substring(0, 1).toUpperCase()
        : 'C';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Clean Booking ID & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatBookingId(booking.id),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  booking.computedStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Customer Profile Section
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF3E8FF),
                backgroundImage: _customerPhoto.isNotEmpty ? NetworkImage(_customerPhoto) : null,
                child: _customerPhoto.isEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          booking.vehicleType.toLowerCase().contains('2') || booking.vehicleType.toLowerCase().contains('bike')
                              ? Icons.two_wheeler
                              : Icons.directions_car,
                          size: 14,
                          color: AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _vehicleDisplay,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_customerPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 12, color: AppColors.greenSuccess),
                          const SizedBox(width: 4),
                          Text(
                            _customerPhone,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.greenSuccess,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),

          // Space, Date & Price Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.spaceTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.bookingDate} • ${booking.timeSlot}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${booking.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Call Customer & Chat Customer
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          partnerId: booking.userId,
                          partnerName: _customerName,
                          partnerPhotoUrl: _customerPhoto,
                          partnerRole: 'Customer (Seeker)',
                          phone: _customerPhone,
                          subtitle: '$_vehicleDisplay • ${booking.timeSlot}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone_outlined, size: 15, color: AppColors.primary),
                  label: const Text(
                    'Call Customer',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          partnerId: booking.userId,
                          partnerName: _customerName,
                          partnerPhotoUrl: _customerPhoto,
                          phone: _customerPhone,
                          spaceTitle: booking.spaceTitle,
                          vehicleInfo: _vehicleDisplay,
                          partnerRole: 'Customer (Seeker)',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 15, color: Colors.white),
                  label: const Text(
                    'Chat Customer',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          if (booking.computedStatus == 'upcoming') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showVerifyOtpDialog(booking),
                icon: const Icon(Icons.pin_outlined, color: Colors.white, size: 16),
                label: const Text('Verify Entry OTP (Check-in Driver)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
              ),
            ),
          ] else if (booking.computedStatus == 'parked') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await FirebaseRtdbService.completeBookingParking(booking.id);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('✅ Vehicle checked out & parking marked as Completed!'),
                        backgroundColor: AppColors.greenSuccess,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                label: const Text('Complete Parking & Release Slot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showVerifyOtpDialog(Booking booking) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.pin_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Verify Entry OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask customer ${_customerName.isNotEmpty ? _customerName : "driver"} for the 4-digit parking entry OTP:'),
            const SizedBox(height: 14),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final entered = otpCtrl.text.trim();
              if (entered.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogCtx).pop();

              final success = await FirebaseRtdbService.verifyBookingEntryOtp(booking.id, entered);
              if (mounted) {
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('🚗 OTP Verified! Vehicle marked as Parked.'),
                      backgroundColor: AppColors.greenSuccess,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('❌ Invalid OTP! Please verify with customer.'),
                      backgroundColor: AppColors.redError,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Verify & Check In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
