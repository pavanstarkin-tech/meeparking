import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_providers.dart';

class MyVehiclesScreen extends ConsumerStatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  ConsumerState<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends ConsumerState<MyVehiclesScreen> {
  void _showAddVehicleDialog() {
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
        builder: (ctx, setLocalState) => Padding(
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
                  if (val != null) setLocalState(() => typeCtrl.text = val);
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
                      final user = ref.read(userProfileProvider);
                      final newVeh = Vehicle(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        number: regNoCtrl.text.trim().toUpperCase(),
                        model: modelCtrl.text.trim(),
                        type: typeCtrl.text,
                      );
                      final nav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      await FirebaseRtdbService.addUserVehicle(user.uid, newVeh);
                      if (ctx.mounted) {
                        nav.pop();
                      }
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Vehicle added successfully!')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Save Vehicle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);
    final vehiclesAsync = ref.watch(userVehiclesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Vehicles', style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Vehicle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Unable to load vehicles')),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No Vehicles Added Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your car, bike, or auto to easily book parking spots with accurate rates.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showAddVehicleDialog,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Vehicle Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final v = vehicles[index];
              final cat = v.category;
              final IconData icon = cat == '2-Wheeler'
                  ? Icons.two_wheeler
                  : cat == '3-Wheeler'
                      ? Icons.electric_rickshaw
                      : Icons.directions_car;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.model, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('Reg No: ${v.number}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                          const SizedBox(height: 4),
                          Text(cat, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () async {
                        await FirebaseRtdbService.deleteUserVehicle(user.uid, v.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vehicle removed')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
