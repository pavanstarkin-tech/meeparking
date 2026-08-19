import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/providers/app_providers.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../partner/partner_onboarding_wizard.dart';
import 'email_verification_screen.dart';
import 'role_details_screen.dart';
import 'role_selection_screen.dart';

/// AuthWrapper monitors authentication and onboarding completion state.
/// Routes users dynamically according to their onboarding status:
/// 1. Unauthenticated -> OnboardingScreen / Login
/// 2. Email Unverified -> EmailVerificationScreen
/// 3. Role Not Chosen -> RoleSelectionScreen
/// 4. Incomplete Seeker Profile -> RoleDetailsScreen(role: 'user')
/// 5. Incomplete Partner Setup -> PartnerOnboardingWizard
/// 6. Fully Onboarded -> HomeScreen (Dashboard)
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state while checking authentication
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

        // Unauthenticated user -> Onboarding & Login Screen
        if (user == null) {
          return const OnboardingScreen();
        }

        // Unverified email -> Email Verification Screen
        if (!user.emailVerified) {
          return EmailVerificationScreen(email: user.email ?? '');
        }

        // Fetch user profile from Firebase RTDB to route properly
        return FutureBuilder<Map<String, dynamic>?>(
          future: FirebaseRtdbService.getUserProfile(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            final data = profileSnap.data;

            // If no profile or role chosen yet -> Role Selection
            if (data == null || data['role'] == null || data['role'].toString().isEmpty) {
              return const RoleSelectionScreen();
            }

            final role = data['role'].toString();

            // Sync Riverpod state
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentRoleProvider.notifier).state = role;
              final profile = ref.read(userProfileProvider);
              if (profile.uid != user.uid || profile.role != role) {
                ref.read(userProfileProvider.notifier).state = profile.copyWith(
                  uid: user.uid,
                  name: (data['name'] ?? user.displayName ?? 'User').toString(),
                  email: (data['email'] ?? user.email ?? '').toString(),
                  phone: (data['phone'] ?? '').toString(),
                  role: role,
                  photoUrl: (data['photoUrl'] ?? user.photoURL ?? profile.photoUrl).toString(),
                );
              }
            });

            // If Seeker ('user'), verify if name and vehicle setup is complete
            if (role == 'user') {
              final hasVehicles = data['vehicles'] != null && (data['vehicles'] as List).isNotEmpty;
              final hasName = data['name'] != null && data['name'].toString().isNotEmpty && data['name'] != 'User';
              if (!hasName || !hasVehicles) {
                return const RoleDetailsScreen(role: 'user');
              }
            }

            // If Partner ('partner'), verify if onboarding was completed
            if (role == 'partner') {
              final isCompleted = data['onboardingCompleted'] == true || data['hasActiveListing'] == true;
              if (!isCompleted) {
                return const PartnerOnboardingWizard();
              }
            }

            // Fully onboarded -> Dashboard!
            return const HomeScreen();
          },
        );
      },
    );
  }
}
