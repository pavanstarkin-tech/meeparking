import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/providers/app_providers.dart';
import '../parking/parking_details_screen.dart';
import '../search/search_parking_screen.dart';

class SavedSpotsScreen extends ConsumerStatefulWidget {
  const SavedSpotsScreen({super.key});

  @override
  ConsumerState<SavedSpotsScreen> createState() => _SavedSpotsScreenState();
}

// Backward compatibility alias for any existing show calls
class SavedSpotsBottomSheet {
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavedSpotsScreen()),
    );
  }
}

class _SavedSpotsScreenState extends ConsumerState<SavedSpotsScreen> {
  Widget _buildSafeImage(String url, {double width = 85, double height = 85}) {
    if (url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.purple.shade50,
        child: const Icon(Icons.local_parking, color: AppColors.primary, size: 28),
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: Colors.purple.shade50,
        child: const Icon(Icons.local_parking, color: AppColors.primary, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryLight, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Parking Spots',
              style: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Your bookmarked favorites',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 18),
          ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: FirebaseRtdbService.streamSavedSpotIds(user.uid),
        builder: (context, savedSnap) {
          final savedIds = savedSnap.data ?? [];

          if (savedSnap.connectionState == ConnectionState.waiting && !savedSnap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (savedIds.isEmpty) {
            return _buildEmptyState();
          }

          return StreamBuilder<List<ParkingSpace>>(
            stream: FirebaseRtdbService.streamParkingSpaces(),
            builder: (context, spacesSnap) {
              if (spacesSnap.connectionState == ConnectionState.waiting && !spacesSnap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final allSpaces = spacesSnap.data ?? [];
              final savedSpaces = allSpaces.where((s) => savedIds.contains(s.id)).toList();

              if (savedSpaces.isEmpty) {
                return _buildEmptyState();
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: savedSpaces.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final space = savedSpaces[index];
                        final price = space.pricing.twoWheeler.hourly > 0
                            ? space.pricing.twoWheeler.hourly.toInt()
                            : (space.pricing.fourWheeler.hourly > 0 ? space.pricing.fourWheeler.hourly.toInt() : 30);
                        final String imageUrl = space.images.isNotEmpty ? space.images.first : '';

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ParkingDetailsScreen(spaceId: space.id)),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _buildSafeImage(imageUrl, width: 80, height: 80),
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
                                              space.title,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimaryLight,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (space.isEvChargingAvailable || space.hasEvCharging)
                                            Container(
                                              margin: const EdgeInsets.only(left: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.greenSuccess.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                '⚡ EV',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.greenSuccess,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        space.address,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '₹$price / hr',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (space.rating > 0) ...[
                                            const SizedBox(width: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${space.rating}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimaryLight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    await FirebaseRtdbService.removeSavedSpot(user.uid, space.id);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('${space.title} removed from saved spots'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 24),
                                  tooltip: 'Remove from Saved',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
                          );
                        },
                        icon: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Explore More Parking Spots',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_border_rounded, size: 54, color: Colors.pink.shade300),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Saved Parking Spots Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the bookmark or heart icon on any parking space to save it here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
                );
              },
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Explore Parking Spots',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
