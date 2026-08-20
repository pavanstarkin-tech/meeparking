import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_providers.dart';
import '../auth/login_screen.dart';

import '../partner/earnings_screen.dart';
import '../partner/partner_payout_screen.dart';
import '../saved/saved_spots_screen.dart';
import '../support/help_support_screen.dart';
import '../vehicles/my_vehicles_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(currentRoleProvider);

    return currentRole == 'partner'
        ? const PartnerProfileView()
        : const SeekerProfileView();
  }
}

/// Helper widget to render Network, Base64 Data URI, or Fallback Icon safely
Widget _buildAvatarImage(String url, {double radius = 40, IconData fallbackIcon = Icons.person}) {
  if (url.isEmpty) {
    return Icon(fallbackIcon, size: radius * 1.1, color: AppColors.primary);
  }
  if (url.startsWith('data:image')) {
    try {
      final base64String = url.split(',').last;
      final bytes = base64Decode(base64String);
      return ClipOval(
        child: Image.memory(
          bytes,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {}
  }
  return ClipOval(
    child: Image.network(
      url,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: radius * 1.1, color: AppColors.primary),
    ),
  );
}

class SeekerProfileView extends ConsumerWidget {
  const SeekerProfileView({super.key});

  void _showEditProfileDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProfileProvider);
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final emailCtrl = TextEditingController(text: user.email);
    final photoCtrl = TextEditingController(text: user.photoUrl);
    bool isUploadingPhoto = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> pickAndUploadPhoto(ImageSource source) async {
            setSheetState(() => isUploadingPhoto = true);
            try {
              final xfile = await CloudinaryService.pickImage(source: source);
              if (xfile != null) {
                final uploadedUrl = await CloudinaryService.uploadImage(xfile);
                if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                  photoCtrl.text = uploadedUrl;
                }
              }
            } catch (e) {
              debugPrint('Photo upload error: $e');
            } finally {
              setSheetState(() => isUploadingPhoto = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Seeker Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Avatar & Direct Upload Button
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: const Color(0xFFF3E8FF),
                                child: isUploadingPhoto
                                    ? const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)
                                    : _buildAvatarImage(photoCtrl.text, radius: 40, fallbackIcon: Icons.person),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: isUploadingPhoto ? null : () => pickAndUploadPhoto(ImageSource.gallery),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: isUploadingPhoto ? null : () => pickAndUploadPhoto(ImageSource.gallery),
                          icon: isUploadingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.primary),
                          label: Text(
                            isUploadingPhoto ? 'Uploading...' : 'Upload Photo directly',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: photoCtrl,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Photo URL',
                      prefixIcon: Icon(Icons.link, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final updatedUser = user.copyWith(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          photoUrl: photoCtrl.text.trim(),
                        );
                        ref.read(userProfileProvider.notifier).state = updatedUser;

                        if (user.uid.isNotEmpty) {
                          await FirebaseRtdbService.updateUserProfile(user.uid, {
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'photoUrl': photoCtrl.text.trim(),
                          });
                        }

                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Seeker Profile updated!'),
                              backgroundColor: AppColors.greenSuccess,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // User Header Profile Info
              Center(
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _showEditProfileDialog(context, ref),
                      borderRadius: BorderRadius.circular(50),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFF3E8FF),
                              child: _buildAvatarImage(user.photoUrl, radius: 40, fallbackIcon: Icons.person),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showEditProfileDialog(context, ref),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isNotEmpty ? user.email : user.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showEditProfileDialog(context, ref),
                      icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                      label: const Text(
                        'Edit Seeker Profile',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Seeker Options List
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(Icons.directions_car_outlined, 'My Vehicles & Registration', () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyVehiclesScreen()));
                    }),
                    _buildDivider(),
                    _buildMenuItem(Icons.bookmark_border, 'My Saved Parking Spots', () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedSpotsScreen()));
                    }),
                    _buildDivider(),
                    _buildMenuItem(Icons.help_outline, 'Help & Driver Support', () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                    }),
                    _buildDivider(),
                    _buildMenuItem(Icons.logout, 'Logout', () async {
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
                    }, isDanger: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDanger = false}) {
    return ListTile(
      leading: Icon(icon, color: isDanger ? AppColors.redError : AppColors.textPrimaryLight, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDanger ? AppColors.redError : AppColors.textPrimaryLight,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryLight),
      onTap: onTap,
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 50, endIndent: 16);
}

class PartnerProfileView extends ConsumerWidget {
  const PartnerProfileView({super.key});

  void _showEditPartnerDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProfileProvider);
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final emailCtrl = TextEditingController(text: user.email);
    final photoCtrl = TextEditingController(text: user.photoUrl);
    bool isUploadingPhoto = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> pickAndUploadLogo(ImageSource source) async {
            setSheetState(() => isUploadingPhoto = true);
            try {
              final xfile = await CloudinaryService.pickImage(source: source);
              if (xfile != null) {
                final uploadedUrl = await CloudinaryService.uploadImage(xfile);
                if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                  photoCtrl.text = uploadedUrl;
                }
              }
            } catch (e) {
              debugPrint('Logo upload error: $e');
            } finally {
              setSheetState(() => isUploadingPhoto = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Partner Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Text(
                    'Upload your store logo / photo and update partner contact details.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 16),

                  // Avatar & Direct Photo Upload Section
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: const Color(0xFFF3E8FF),
                                child: isUploadingPhoto
                                    ? const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)
                                    : _buildAvatarImage(photoCtrl.text, radius: 42, fallbackIcon: Icons.storefront),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: isUploadingPhoto ? null : () => pickAndUploadLogo(ImageSource.gallery),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: isUploadingPhoto ? null : () => pickAndUploadLogo(ImageSource.gallery),
                          icon: isUploadingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : const Icon(Icons.upload_file_outlined, size: 16, color: AppColors.primary),
                          label: Text(
                            isUploadingPhoto ? 'Uploading Logo...' : 'Upload Logo directly from Device',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Partner / Business Name *',
                      prefixIcon: Icon(Icons.business_outlined, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email Address',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: photoCtrl,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Logo / Photo URL (Or use Upload above)',
                      prefixIcon: Icon(Icons.link, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final updatedName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : user.name;
                        final updatedPhone = phoneCtrl.text.trim();
                        final updatedEmail = emailCtrl.text.trim();
                        final updatedPhoto = photoCtrl.text.trim();

                        final updatedUser = user.copyWith(
                          name: updatedName,
                          phone: updatedPhone,
                          email: updatedEmail,
                          photoUrl: updatedPhoto,
                        );

                        ref.read(userProfileProvider.notifier).state = updatedUser;

                        if (user.uid.isNotEmpty) {
                          await FirebaseRtdbService.updateUserProfile(user.uid, {
                            'name': updatedName,
                            'phone': updatedPhone,
                            'email': updatedEmail,
                            'photoUrl': updatedPhoto,
                          });
                        }

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Partner profile & logo updated!'),
                              backgroundColor: AppColors.greenSuccess,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Partner Header Info
              Center(
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _showEditPartnerDialog(context, ref),
                      borderRadius: BorderRadius.circular(50),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor: const Color(0xFFF3E8FF),
                              child: _buildAvatarImage(user.photoUrl, radius: 42, fallbackIcon: Icons.storefront),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showEditPartnerDialog(context, ref),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.edit, size: 15, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Verified Parking Partner & Property Owner',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    // Contact Details Row
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (user.phone.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondaryLight),
                                const SizedBox(width: 5),
                                Text(user.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                              ],
                            ),
                          ),
                        if (user.email.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.email_outlined, size: 13, color: AppColors.textSecondaryLight),
                                const SizedBox(width: 5),
                                Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () => _showEditPartnerDialog(context, ref),
                      icon: const Icon(Icons.edit_note_rounded, size: 17, color: AppColors.primary),
                      label: const Text(
                        'Edit Partner & Contact Details',
                        style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Partner Options List
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(Icons.account_balance_outlined, 'Bank Account & Payout Setup', () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerPayoutScreen()));
                    }),
                    _buildDivider(),
                    _buildMenuItem(Icons.bar_chart_rounded, 'Earnings Analytics & Revenue', () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarningsScreen()));
                    }),
                    _buildDivider(),
                    _buildMenuItem(Icons.support_agent_outlined, 'Partner Support 24/7', () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                    }),
                    _buildDivider(),
                    _buildMenuItem(Icons.logout, 'Logout', () async {
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
                    }, isDanger: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDanger = false}) {
    return ListTile(
      leading: Icon(icon, color: isDanger ? AppColors.redError : AppColors.textPrimaryLight, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDanger ? AppColors.redError : AppColors.textPrimaryLight,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryLight),
      onTap: onTap,
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 50, endIndent: 16);
}
