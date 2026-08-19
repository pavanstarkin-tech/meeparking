import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/providers/app_providers.dart';
import '../parking/parking_details_screen.dart';
import '../search/search_parking_screen.dart';

class SavedSpotsBottomSheet extends ConsumerStatefulWidget {
  const SavedSpotsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SavedSpotsBottomSheet(),
    );
  }

  @override
  ConsumerState<SavedSpotsBottomSheet> createState() => _SavedSpotsBottomSheetState();
}

class _SavedSpotsBottomSheetState extends ConsumerState<SavedSpotsBottomSheet> {
  Widget _buildSafeImage(String url, {double width = 75, double height = 75}) {
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved Spots',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                      ),
                      Text(
                        'Your bookmarked parking spaces',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondaryLight, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Realtime Stream of ONLY User's Truly Saved Parking Spaces from RTDB
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: FirebaseRtdbService.streamSavedSpotIds(user.uid),
              builder: (context, savedSnap) {
                final savedIds = savedSnap.data ?? [];

                if (savedSnap.connectionState == ConnectionState.waiting && !savedSnap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                // If user has 0 saved spots in RTDB
                if (savedIds.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.favorite_border_rounded, size: 48, color: Colors.pink.shade300),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No saved parking spots yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                        ),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Tap the heart icon on any parking spot in Search or Details to bookmark it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Match saved IDs against live database parking spaces
                return StreamBuilder<List<ParkingSpace>>(
                  stream: FirebaseRtdbService.streamParkingSpaces(),
                  builder: (context, spacesSnap) {
                    final allSpaces = spacesSnap.data ?? [];
                    final savedSpaces = allSpaces.where((s) => savedIds.contains(s.id)).toList();

                    if (savedSpaces.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.pink.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.favorite_border_rounded, size: 48, color: Colors.pink.shade300),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No saved parking spots',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Your saved listings will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: savedSpaces.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final space = savedSpaces[index];
                        final price = space.pricing.twoWheeler.hourly > 0
                            ? space.pricing.twoWheeler.hourly.toInt()
                            : (space.pricing.fourWheeler.hourly > 0 ? space.pricing.fourWheeler.hourly.toInt() : 30);
                        final String imageUrl = space.images.isNotEmpty ? space.images.first : '';

                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ParkingDetailsScreen(spaceId: space.id)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildSafeImage(imageUrl, width: 70, height: 70),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              space.title,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (space.isEvChargingAvailable || space.hasEvCharging)
                                            Container(
                                              margin: const EdgeInsets.only(left: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.greenSuccess.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'EV ⚡',
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.greenSuccess),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        space.address,
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '₹$price / hr',
                                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          if (space.rating > 0) ...[
                                            const SizedBox(width: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${space.rating}',
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Interactive Remove Bookmark Button (Deletes permanently from RTDB)
                                IconButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    await FirebaseRtdbService.removeSavedSpot(user.uid, space.id);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('${space.title} removed from saved spots'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
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
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Bottom Search CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
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
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SavedSpotsScreen extends StatelessWidget {
  const SavedSpotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Saved Spots', style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const SavedSpotsBottomSheet(),
    );
  }
}
