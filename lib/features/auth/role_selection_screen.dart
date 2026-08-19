import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/providers/app_providers.dart';
import '../partner/partner_onboarding_wizard.dart';
import 'role_details_screen.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    // Card 1: Parking Seeker -> Goes to Seeker Profile setup
                    Expanded(
                      child: _buildGridRoleCard(
                        context: context,
                        ref: ref,
                        title: 'Parking Seeker',
                        subtitle: 'Find & Book Spot',
                        badgeText: 'PARK SMART',
                        badgeColor: AppColors.greenSuccess,
                        icon: Icons.directions_car_filled_outlined,
                        cardBg: const Color(0xFFF0FDF4),
                        borderColor: AppColors.greenSuccess.withOpacity(0.4),
                        iconBg: Colors.white,
                        iconColor: AppColors.greenSuccess,
                        onTap: () {
                          ref.read(currentRoleProvider.notifier).state = 'user';
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RoleDetailsScreen(role: 'user'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Card 2: Parking Partner -> Directs directly to Partner Onboarding Wizard!
                    Expanded(
                      child: _buildGridRoleCard(
                        context: context,
                        ref: ref,
                        title: 'Parking Partner',
                        subtitle: 'List Space & Earn',
                        badgeText: 'EARN DAILY',
                        badgeColor: AppColors.primary,
                        icon: Icons.storefront_outlined,
                        cardBg: const Color(0xFFFBF7FF),
                        borderColor: AppColors.primary.withOpacity(0.4),
                        iconBg: Colors.white,
                        iconColor: AppColors.primary,
                        onTap: () async {
                          ref.read(currentRoleProvider.notifier).state = 'partner';
                          final user = AuthService.currentUser;
                          if (user != null) {
                            await FirebaseRtdbService.updateUserProfile(user.uid, {
                              'role': 'partner',
                              'email': user.email ?? '',
                              'uid': user.uid,
                            });
                          }
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PartnerOnboardingWizard(),
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
          ),
        ],
      ),
    );
  }

  Widget _buildGridRoleCard({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color cardBg,
    required Color borderColor,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.14),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Icon Circle
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),

            // Select button pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 13, color: iconColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
