import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Streamlined Primary Hero Illustration Widget matching Screen 02 & Screen 11
class MeeParkingCarIllustration extends StatelessWidget {
  final double width;
  final double height;
  final bool showBadge;

  const MeeParkingCarIllustration({
    super.key,
    this.width = 240,
    this.height = 140,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/illustrations/onboarding_car_illustration.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackVector(width, height),
      ),
    );
  }

  Widget _buildFallbackVector(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Icon(Icons.directions_car, size: 64, color: AppColors.primary),
      ),
    );
  }
}

/// Hero Illustration Widget for Booking Confirmed (Screen 07)
class MeeParkingBookingConfirmedIllustration extends StatelessWidget {
  final double width;
  final double height;

  const MeeParkingBookingConfirmedIllustration({
    super.key,
    this.width = 220,
    this.height = 130,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/illustrations/booking_confirmed_illustration.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const MeeParkingCarIllustration(width: 220, height: 130, showBadge: false),
      ),
    );
  }
}

/// 3D Wallet Illustration Widget (Screen 10)
class MeeParkingWalletIllustration extends StatelessWidget {
  final double size;

  const MeeParkingWalletIllustration({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/new-assets/wallet.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.account_balance_wallet, size: size * 0.7, color: Colors.white),
      ),
    );
  }
}

/// Partner Garage Illustration Widget (Screen 11)
class MeeParkingPartnerGarageIllustration extends StatelessWidget {
  final double width;
  final double height;

  const MeeParkingPartnerGarageIllustration({
    super.key,
    this.width = 220,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/illustrations/partner_garage_illustration.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const MeeParkingCarIllustration(width: 220, height: 120, showBadge: true),
      ),
    );
  }
}
