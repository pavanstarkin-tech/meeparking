import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/providers/app_providers.dart';
import 'partner_add_space_stepper_sheet.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  void _showAddListingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PartnerAddSpaceStepperSheet(),
    );
  }

  void _showEditListingDialog(BuildContext context, ParkingSpace space) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartnerAddSpaceStepperSheet(existingSpace: space),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddListingDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Parking Spot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ParkingSpace>>(
          stream: FirebaseRtdbService.streamPartnerSpaces(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            final listings = snapshot.data ?? [];

            if (listings.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3E8FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.maps_home_work_outlined, size: 56, color: AppColors.primary),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No listings added yet',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Register your driveway or parking garage to start receiving customer bookings and earning revenue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddListingDialog,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Add Your First Spot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final space = listings[index];
                return _buildListingCard(space);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleListingStatus(ParkingSpace space) async {
    final newStatus = space.isActive ? 'inactive' : 'active';
    final updatedSpace = ParkingSpace(
      id: space.id,
      ownerId: space.ownerId,
      title: space.title,
      address: space.address,
      city: space.city,
      lat: space.lat,
      lng: space.lng,
      images: space.images,
      description: space.description,
      amenities: space.amenities,
      capacity: space.capacity,
      pricing: space.pricing,
      status: newStatus,
      rating: space.rating,
      reviewCount: space.reviewCount,
      distanceKm: space.distanceKm,
      hasEvCharging: space.hasEvCharging,
      polygonCoordinates: space.polygonCoordinates,
    );

    await FirebaseRtdbService.addParkingSpace(updatedSpace);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'active'
                ? 'Listing marked as ACTIVE live on explore map!'
                : 'Listing marked as INACTIVE (Hidden from seekers)',
          ),
          backgroundColor: newStatus == 'active' ? AppColors.greenSuccess : AppColors.orangeWarning,
        ),
      );
    }
  }

  Widget _buildListingCard(ParkingSpace space) {
    final carRate = space.pricing.fourWheeler.hourly.toInt();
    final bikeRate = space.pricing.twoWheeler.hourly.toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showEditListingDialog(context, space),
          onLongPress: () => _toggleListingStatus(space),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        space.images.first,
                        width: 75,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 75,
                          height: 75,
                          color: Colors.purple.shade50,
                          child: const Icon(Icons.local_parking, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 36.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              space.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              space.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Car: ₹$carRate/hr',
                                    style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.greenSuccess.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Bike: ₹$bikeRate/hr',
                                    style: const TextStyle(fontSize: 10, color: AppColors.greenSuccess, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hold card to toggle Active status',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Active / Inactive Status Label in Top Right Corner
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: space.isActive ? AppColors.greenSuccess.withOpacity(0.15) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      space.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: space.isActive ? AppColors.greenSuccess : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),

                // Edit Icon in Middle Right Side
                Positioned(
                  right: 0,
                  top: 36,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
