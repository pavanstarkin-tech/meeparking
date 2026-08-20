import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config/env_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../core/services/mapbox_geocoding_service.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/providers/app_providers.dart';

class PartnerAddSpaceStepperSheet extends ConsumerStatefulWidget {
  final ParkingSpace? existingSpace;

  const PartnerAddSpaceStepperSheet({super.key, this.existingSpace});

  @override
  ConsumerState<PartnerAddSpaceStepperSheet> createState() => _PartnerAddSpaceStepperSheetState();
}

class _PartnerAddSpaceStepperSheetState extends ConsumerState<PartnerAddSpaceStepperSheet> {
  int _currentStep = 0;

  // Step 1: Identity & Images
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  final List<String> _uploadedImageUrls = [];
  final List<XFile> _localImageFiles = [];
  final List<Uint8List> _localImageBytes = [];
  bool _isUploadingPhoto = false;

  // Step 2: Interactive Map Polygon & Dynamic Capacity Math
  final List<LatLng> _polygonPoints = [];
  late MapController _mapController;
  LatLng _mapCenter = const LatLng(28.6315, 77.2167);
  bool _isLocating = false;

  // Step 3: Vehicle Type Pricing Matrix (2-Wheeler, 3-Wheeler, 4-Wheeler x 4 Time Rates)
  late TextEditingController _twoWheelerHourlyCtrl;
  late TextEditingController _twoWheelerDailyCtrl;
  late TextEditingController _twoWheelerWeeklyCtrl;
  late TextEditingController _twoWheelerMonthlyCtrl;

  late TextEditingController _threeWheelerHourlyCtrl;
  late TextEditingController _threeWheelerDailyCtrl;
  late TextEditingController _threeWheelerWeeklyCtrl;
  late TextEditingController _threeWheelerMonthlyCtrl;

  late TextEditingController _fourWheelerHourlyCtrl;
  late TextEditingController _fourWheelerDailyCtrl;
  late TextEditingController _fourWheelerWeeklyCtrl;
  late TextEditingController _fourWheelerMonthlyCtrl;

  // Step 4: Lot Features & Amenities (16 Expanded Amenities)
  final Map<String, bool> _amenitiesMap = {
    'CCTV Surveillance': false,
    'Covered Parking': false,
    '24/7 Security Guard': false,
    'EV Fast Charger': false,
    'Valet Parking': false,
    'Automated Gate': false,
    'Wheelchair Accessible': false,
    'Car Wash & Detailing': false,
    'Restroom / Washroom': false,
    'Driver Lounge': false,
    'Tyre Inflator / Air': false,
    'Shuttle Service': false,
    'Night Floodlights': false,
    'Boom Barrier Entry': false,
    'Emergency Helpline': false,
    'Underground Deck': false,
  };

  // Step 5: Dynamic Reverse Geocoding & Confirmation
  String _reverseGeocodedAddress = '';
  String _reverseGeocodedCity = '';
  bool _isFetchingAddress = false;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    final space = widget.existingSpace;
    _titleCtrl = TextEditingController(text: space?.title ?? '');
    _descCtrl = TextEditingController(text: space?.description ?? '');

    if (space != null) {
      _uploadedImageUrls.addAll(space.images);
      _mapCenter = LatLng(space.lat, space.lng);
      if (space.polygonCoordinates != null && space.polygonCoordinates!.isNotEmpty) {
        for (final pt in space.polygonCoordinates!) {
          _polygonPoints.add(LatLng(pt[0], pt[1]));
        }
      }
      _reverseGeocodedAddress = space.address;
      _reverseGeocodedCity = space.city;
    }

    // Step 3 Pricing Matrix Controllers
    final p = space?.pricing;
    _twoWheelerHourlyCtrl = TextEditingController(text: p != null ? '${p.twoWheeler.hourly.toInt()}' : '30');
    _twoWheelerDailyCtrl = TextEditingController(text: p != null ? '${p.twoWheeler.daily.toInt()}' : '150');
    _twoWheelerWeeklyCtrl = TextEditingController(text: p != null ? '${p.twoWheeler.weekly.toInt()}' : '750');
    _twoWheelerMonthlyCtrl = TextEditingController(text: p != null ? '${p.twoWheeler.monthly.toInt()}' : '2250');

    _threeWheelerHourlyCtrl = TextEditingController(text: p != null ? '${p.threeWheeler.hourly.toInt()}' : '45');
    _threeWheelerDailyCtrl = TextEditingController(text: p != null ? '${p.threeWheeler.daily.toInt()}' : '225');
    _threeWheelerWeeklyCtrl = TextEditingController(text: p != null ? '${p.threeWheeler.weekly.toInt()}' : '1125');
    _threeWheelerMonthlyCtrl = TextEditingController(text: p != null ? '${p.threeWheeler.monthly.toInt()}' : '3375');

    _fourWheelerHourlyCtrl = TextEditingController(text: p != null ? '${p.fourWheeler.hourly.toInt()}' : '60');
    _fourWheelerDailyCtrl = TextEditingController(text: p != null ? '${p.fourWheeler.daily.toInt()}' : '300');
    _fourWheelerWeeklyCtrl = TextEditingController(text: p != null ? '${p.fourWheeler.weekly.toInt()}' : '1500');
    _fourWheelerMonthlyCtrl = TextEditingController(text: p != null ? '${p.fourWheeler.monthly.toInt()}' : '4500');

    if (space != null) {
      for (final a in space.amenities) {
        final clean = ParkingSpace.sanitizeAmenity(a);
        _amenitiesMap[clean] = true;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _twoWheelerHourlyCtrl.dispose();
    _twoWheelerDailyCtrl.dispose();
    _twoWheelerWeeklyCtrl.dispose();
    _twoWheelerMonthlyCtrl.dispose();
    _threeWheelerHourlyCtrl.dispose();
    _threeWheelerDailyCtrl.dispose();
    _threeWheelerWeeklyCtrl.dispose();
    _threeWheelerMonthlyCtrl.dispose();
    _fourWheelerHourlyCtrl.dispose();
    _fourWheelerDailyCtrl.dispose();
    _fourWheelerWeeklyCtrl.dispose();
    _fourWheelerMonthlyCtrl.dispose();
    super.dispose();
  }

  // Geodesic Polygon Area Calculation in Square Meters (m²)
  double _calculatePolygonAreaSqMeters() {
    if (_polygonPoints.length < 3) return 0.0;
    double totalArea = 0.0;
    const radiusOfEarth = 6378137.0; // Earth WGS84 radius in meters

    for (int i = 0; i < _polygonPoints.length; i++) {
      final p1 = _polygonPoints[i];
      final p2 = _polygonPoints[(i + 1) % _polygonPoints.length];

      final lat1 = p1.latitude * math.pi / 180.0;
      final lng1 = p1.longitude * math.pi / 180.0;
      final lat2 = p2.latitude * math.pi / 180.0;
      final lng2 = p2.longitude * math.pi / 180.0;

      totalArea += (lng2 - lng1) * (2.0 + math.sin(lat1) + math.sin(lat2));
    }

    totalArea = (totalArea * radiusOfEarth * radiusOfEarth / 2.0).abs();
    return totalArea;
  }

  int get _calculatedMaxCars {
    final area = _calculatePolygonAreaSqMeters();
    if (area <= 0) return 18;
    return (area / 12.5).floor().clamp(1, 200);
  }

  int get _calculatedMaxBikes {
    final area = _calculatePolygonAreaSqMeters();
    if (area <= 0) return 30;
    return (area / 2.5).floor().clamp(2, 400);
  }

  // Reverse Geocoding via Mapbox API
  Future<void> _fetchDynamicAddress() async {
    setState(() => _isFetchingAddress = true);
    final centerLat = _polygonPoints.isNotEmpty
        ? _polygonPoints.map((p) => p.latitude).reduce((a, b) => a + b) / _polygonPoints.length
        : _mapCenter.latitude;
    final centerLng = _polygonPoints.isNotEmpty
        ? _polygonPoints.map((p) => p.longitude).reduce((a, b) => a + b) / _polygonPoints.length
        : _mapCenter.longitude;

    final geoResult = await MapboxGeocodingService.reverseGeocode(centerLat, centerLng);
    if (mounted) {
      setState(() {
        _reverseGeocodedAddress = geoResult.fullAddress;
        _reverseGeocodedCity = geoResult.city;
        if (_titleCtrl.text.isEmpty) {
          _titleCtrl.text = geoResult.title;
        }
        _isFetchingAddress = false;
      });
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        final currentLatLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _mapCenter = currentLatLng;
        });
        _mapController.move(currentLatLng, 16.5);
      }
    } catch (_) {}
    setState(() => _isLocating = false);
  }

  Future<void> _publishListing() async {
    setState(() => _isPublishing = true);

    final user = ref.read(userProfileProvider);
    final centerLat = _polygonPoints.isNotEmpty
        ? _polygonPoints.map((p) => p.latitude).reduce((a, b) => a + b) / _polygonPoints.length
        : _mapCenter.latitude;
    final centerLng = _polygonPoints.isNotEmpty
        ? _polygonPoints.map((p) => p.longitude).reduce((a, b) => a + b) / _polygonPoints.length
        : _mapCenter.longitude;

    final areaSqM = _calculatePolygonAreaSqMeters();
    final polyCoords = _polygonPoints.map((p) => [p.latitude, p.longitude]).toList();

    final selectedAmenities = _amenitiesMap.entries.where((e) => e.value).map((e) => e.key).toList();

    final spaceToSave = ParkingSpace(
      id: widget.existingSpace?.id ?? 'space_${DateTime.now().millisecondsSinceEpoch}',
      ownerId: widget.existingSpace?.ownerId ?? (user.uid.isNotEmpty ? user.uid : 'owner_1'),
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : (widget.existingSpace?.title ?? 'My Parking Space'),
      address: _reverseGeocodedAddress.trim().isNotEmpty ? _reverseGeocodedAddress.trim() : (widget.existingSpace?.address ?? 'Connaught Place, Delhi'),
      city: _reverseGeocodedCity.trim().isNotEmpty ? _reverseGeocodedCity.trim() : (widget.existingSpace?.city ?? 'Delhi NCR'),
      lat: centerLat,
      lng: centerLng,
      images: _uploadedImageUrls.isNotEmpty
          ? List<String>.from(_uploadedImageUrls)
          : (widget.existingSpace?.images ?? []),
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : (widget.existingSpace?.description ?? 'Verified parking slot with digital boundary reservation.'),
      amenities: selectedAmenities.isNotEmpty ? selectedAmenities : (widget.existingSpace?.amenities ?? ['CCTV Surveillance', 'Covered Parking']),
      capacity: LandCapacity(
        totalLandSqMeters: areaSqM > 0 ? areaSqM : (widget.existingSpace?.capacity.totalLandSqMeters ?? 150.0),
        maxCars: _calculatedMaxCars,
        maxBikes: _calculatedMaxBikes,
        currentCars: widget.existingSpace?.capacity.currentCars ?? 0,
        currentBikes: widget.existingSpace?.capacity.currentBikes ?? 0,
      ),
      pricing: ParkingPricing(
        hourly: double.tryParse(_fourWheelerHourlyCtrl.text) ?? 60.0,
        daily: double.tryParse(_fourWheelerDailyCtrl.text) ?? 300.0,
        weekly: double.tryParse(_fourWheelerWeeklyCtrl.text) ?? 1500.0,
        monthly: double.tryParse(_fourWheelerMonthlyCtrl.text) ?? 4500.0,
        twoWheeler: VehicleCategoryRates(
          hourly: double.tryParse(_twoWheelerHourlyCtrl.text) ?? 30.0,
          daily: double.tryParse(_twoWheelerDailyCtrl.text) ?? 150.0,
          weekly: double.tryParse(_twoWheelerWeeklyCtrl.text) ?? 750.0,
          monthly: double.tryParse(_twoWheelerMonthlyCtrl.text) ?? 2250.0,
        ),
        threeWheeler: VehicleCategoryRates(
          hourly: double.tryParse(_threeWheelerHourlyCtrl.text) ?? 45.0,
          daily: double.tryParse(_threeWheelerDailyCtrl.text) ?? 225.0,
          weekly: double.tryParse(_threeWheelerWeeklyCtrl.text) ?? 1125.0,
          monthly: double.tryParse(_threeWheelerMonthlyCtrl.text) ?? 3375.0,
        ),
        fourWheeler: VehicleCategoryRates(
          hourly: double.tryParse(_fourWheelerHourlyCtrl.text) ?? 60.0,
          daily: double.tryParse(_fourWheelerDailyCtrl.text) ?? 300.0,
          weekly: double.tryParse(_fourWheelerWeeklyCtrl.text) ?? 1500.0,
          monthly: double.tryParse(_fourWheelerMonthlyCtrl.text) ?? 4500.0,
        ),
      ),
      status: widget.existingSpace?.status ?? 'pending_approval',
      rating: widget.existingSpace?.rating ?? 5.0,
      reviewCount: widget.existingSpace?.reviewCount ?? 0,
      distanceKm: widget.existingSpace?.distanceKm ?? 1.2,
      hasEvCharging: selectedAmenities.any((a) => a.contains('EV')),
      polygonCoordinates: polyCoords.isNotEmpty ? polyCoords : widget.existingSpace?.polygonCoordinates,
    );

    await FirebaseRtdbService.addParkingSpace(spaceToSave, partnerDetails: {
      'name': user.name,
      'phone': user.phone,
      'email': user.email,
      'uid': user.uid,
    });

    setState(() => _isPublishing = false);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingSpace != null
                ? 'Parking Slot updated successfully!'
                : 'Parking Slot submitted! Request sent to Admin for approval.',
          ),
          backgroundColor: AppColors.greenSuccess,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.existingSpace != null ? 'Edit Parking Slot' : 'Add Parking Slot Wizard',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Stepper Header
          _buildStepProgressHeader(),
          const SizedBox(height: 14),

          // Step Body Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildCurrentStepContent(),
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Stepper Buttons
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentStep--),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isPublishing
                      ? null
                      : () async {
                          // Validate Step 0: Min 4 images for new space
                          if (_currentStep == 0) {
                            final totalImages = _uploadedImageUrls.length + _localImageFiles.length;
                            if (widget.existingSpace == null && totalImages < 4) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Please upload at least 4 photos of the parking space ($totalImages/4 uploaded).',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.redError,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                              return;
                            }
                          }

                          if (_currentStep < 4) {
                            if (_currentStep == 3) {
                              await _fetchDynamicAddress();
                            }
                            setState(() => _currentStep++);
                          } else {
                            _publishListing();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isPublishing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _currentStep == 4
                              ? (widget.existingSpace != null ? 'Save Changes' : 'Confirm & Submit to Admin')
                              : 'Next Step ➔',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressHeader() {
    final stepTitles = ['Slot Identity', 'Map & Area', 'Vehicle Pricing', 'Amenities', 'Confirm & Publish'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${_currentStep + 1} of 5: ${stepTitles[_currentStep]}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            Text('${((_currentStep + 1) * 20)}% Complete', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentStep + 1) / 5,
          backgroundColor: Colors.purple.shade50,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1SlotIdentity();
      case 1:
        return _buildStep2MapPolygonMarking();
      case 2:
        return _buildStep3VehicleTypePricingMatrix();
      case 3:
        return _buildStep4Amenities();
      case 4:
        return _buildStep5DynamicAddressAndReview();
      default:
        return Container();
    }
  }

  // STEP 1: Parking Slot Identity & Images
  Widget _buildStep1SlotIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Parking Slot Identity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Parking Slot Name (e.g. Connaught Place Garage)',
            prefixIcon: Icon(Icons.storefront),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Description / Access Instructions',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Upload Parking Slot Images', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        ElevatedButton.icon(
          onPressed: _isUploadingPhoto
              ? null
              : () async {
                  final file = await CloudinaryService.pickImage();
                  if (file != null) {
                    final bytes = await file.readAsBytes();
                    setState(() {
                      _localImageFiles.add(file);
                      _localImageBytes.add(bytes);
                      _isUploadingPhoto = true;
                    });
                    final url = await CloudinaryService.uploadImage(file);
                    if (url != null && url.isNotEmpty) {
                      setState(() {
                        _uploadedImageUrls.add(url);
                      });
                    }
                    setState(() => _isUploadingPhoto = false);
                  }
                },
          icon: _isUploadingPhoto
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
          label: const Text('Pick & Upload Photo to Cloudinary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
        ),
        const SizedBox(height: 12),

        if (_uploadedImageUrls.isNotEmpty || _localImageFiles.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._localImageBytes.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final bytes = entry.value;
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(bytes, width: 95, height: 95, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _localImageBytes.removeAt(idx);
                              if (idx < _localImageFiles.length) {
                                _localImageFiles.removeAt(idx);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.redError,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                ..._uploadedImageUrls.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final url = entry.value;
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url, width: 95, height: 95, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _uploadedImageUrls.removeAt(idx);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.redError,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  // STEP 2: Interactive Map Polygon Marking & Dynamic Area/Capacity Math
  Widget _buildStep2MapPolygonMarking() {
    final areaSqM = _calculatePolygonAreaSqMeters();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tap Map to Add Boundary Dots', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            IconButton(
              icon: _isLocating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location, color: AppColors.primary),
              tooltip: 'Go to Current Position',
              onPressed: _goToCurrentLocation,
            ),
          ],
        ),
        const Text(
          'Tap points on the map to define the boundary polygon of your parking area.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 10),

        // Interactive FlutterMap View
        Container(
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: 17.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _polygonPoints.add(point);
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: EnvConfig.mapboxTileUrl,
                  userAgentPackageName: 'com.meeparking.app',
                ),
                if (_polygonPoints.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _polygonPoints,
                        color: AppColors.primary.withOpacity(0.3),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 3,
                        isFilled: true,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // Live Current Location GPS Pointer Pin
                    Marker(
                      point: _mapCenter,
                      width: 44,
                      height: 44,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.25),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10, spreadRadius: 2),
                          ],
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                    ..._polygonPoints.map((pt) {
                      return Marker(
                        point: pt,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.circle, color: Colors.white, size: 10),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _polygonPoints.isNotEmpty
                  ? () {
                      setState(() {
                        _polygonPoints.removeLast();
                      });
                    }
                  : null,
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Undo Dot'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _polygonPoints.isNotEmpty
                  ? () {
                      setState(() {
                        _polygonPoints.clear();
                      });
                    }
                  : null,
              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.redError),
              label: const Text('Clear All', style: TextStyle(color: AppColors.redError)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Live Dynamic Calculations Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dynamic Area & Capacity Calculations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCalcMetric('Calculated Area', '${areaSqM.toStringAsFixed(1)} m²'),
                  _buildCalcMetric('Max Car Capacity', '$_calculatedMaxCars Cars'),
                  _buildCalcMetric('Max Bike Capacity', '$_calculatedMaxBikes Bikes'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalcMetric(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
      ],
    );
  }

  // STEP 3: Vehicle Type Pricing Matrix (2-Wheeler, 3-Wheeler, 4-Wheeler x 4 Time Rates)
  Widget _buildStep3VehicleTypePricingMatrix() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vehicle Type Pricing Matrix (₹)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Configure per hour, per day, per week, and per month charges for each vehicle category.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 14),

        // 4-Wheeler Section
        _buildVehiclePricingSection('4-Wheeler (Car / SUV)', Icons.directions_car, AppColors.primary, _fourWheelerHourlyCtrl, _fourWheelerDailyCtrl, _fourWheelerWeeklyCtrl, _fourWheelerMonthlyCtrl),
        const SizedBox(height: 16),

        // 2-Wheeler Section
        _buildVehiclePricingSection('2-Wheeler (Bike / Scooter)', Icons.two_wheeler, AppColors.greenSuccess, _twoWheelerHourlyCtrl, _twoWheelerDailyCtrl, _twoWheelerWeeklyCtrl, _twoWheelerMonthlyCtrl),
        const SizedBox(height: 16),

        // 3-Wheeler Section
        _buildVehiclePricingSection('3-Wheeler (Auto / E-Rickshaw)', Icons.electric_rickshaw, Colors.orange, _threeWheelerHourlyCtrl, _threeWheelerDailyCtrl, _threeWheelerWeeklyCtrl, _threeWheelerMonthlyCtrl),
      ],
    );
  }

  Widget _buildVehiclePricingSection(
    String categoryName,
    IconData icon,
    Color color,
    TextEditingController hrCtrl,
    TextEditingController dayCtrl,
    TextEditingController wkCtrl,
    TextEditingController moCtrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(categoryName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: hrCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per Hour (₹)', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: dayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per Day (₹)', border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: wkCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per Week (₹)', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: moCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per Month (₹)', border: OutlineInputBorder()))),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 4: Lot Amenities & Features
  Widget _buildStep4Amenities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lot Features & Amenities', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Select all features available at this parking location.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _amenitiesMap.keys.map((amenity) {
            final clean = ParkingSpace.sanitizeAmenity(amenity);
            final isChecked = _amenitiesMap[amenity] ?? _amenitiesMap[clean] ?? false;
            return FilterChip(
              label: Text(clean, style: TextStyle(fontWeight: isChecked ? FontWeight.bold : FontWeight.normal)),
              selected: isChecked,
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onSelected: (val) {
                setState(() {
                  _amenitiesMap[amenity] = val;
                  _amenitiesMap[clean] = val;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // STEP 5: Complete Exhaustive Review & Dynamic Address Confirmation
  Widget _buildStep5DynamicAddressAndReview() {
    final areaSqM = _calculatePolygonAreaSqMeters();
    final selectedAmenities = _amenitiesMap.entries.where((e) => e.value).map((e) => e.key).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Confirm & Publish Listing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 4),
        const Text('Review all slot details from Step 1 to Step 4 before publishing live.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 14),

        // SECTION 1: Identity & Photos (From Step 1)
        _buildReviewCardSection(
          title: '1. Slot Identity & Photos',
          icon: Icons.storefront,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Untitled Parking Slot', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              if (_descCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(_descCtrl.text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
              const SizedBox(height: 10),
              if (_uploadedImageUrls.isNotEmpty || _localImageFiles.isNotEmpty)
                SizedBox(
                  height: 70,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._localImageBytes.map((bytes) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(bytes, width: 70, height: 70, fit: BoxFit.cover)),
                          )),
                      ..._uploadedImageUrls.map((url) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 70, height: 70, fit: BoxFit.cover)),
                          )),
                    ],
                  ),
                )
              else
                const Text('No photos attached', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // SECTION 2: Dynamic Location & Map Area Calculations (From Step 2)
        _buildReviewCardSection(
          title: '2. Dynamic Location & Area Math',
          icon: Icons.map_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: AppColors.redError, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _isFetchingAddress
                        ? const Text('Fetching street address from map coordinates...', style: TextStyle(fontSize: 12, color: Colors.grey))
                        : Text(_reverseGeocodedAddress.isNotEmpty ? _reverseGeocodedAddress : 'Selected Area Coordinates', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryBadge('Total Area', '${areaSqM.toStringAsFixed(1)} m²', AppColors.primary),
                  _buildSummaryBadge('Max Cars', '$_calculatedMaxCars Slots', AppColors.greenSuccess),
                  _buildSummaryBadge('Max Bikes', '$_calculatedMaxBikes Slots', Colors.orange),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // SECTION 3: Vehicle Type Pricing Matrix (From Step 3)
        _buildReviewCardSection(
          title: '3. Vehicle Pricing Matrix',
          icon: Icons.payments_outlined,
          child: Column(
            children: [
              _buildReviewPricingRow('Car (4-Wheeler)', '₹${_fourWheelerHourlyCtrl.text}/hr', '₹${_fourWheelerDailyCtrl.text}/day', '₹${_fourWheelerMonthlyCtrl.text}/mo', AppColors.primary),
              const Divider(height: 12),
              _buildReviewPricingRow('Bike (2-Wheeler)', '₹${_twoWheelerHourlyCtrl.text}/hr', '₹${_twoWheelerDailyCtrl.text}/day', '₹${_twoWheelerMonthlyCtrl.text}/mo', AppColors.greenSuccess),
              const Divider(height: 12),
              _buildReviewPricingRow('Auto (3-Wheeler)', '₹${_threeWheelerHourlyCtrl.text}/hr', '₹${_threeWheelerDailyCtrl.text}/day', '₹${_threeWheelerMonthlyCtrl.text}/mo', Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // SECTION 4: Features & Amenities (From Step 4)
        _buildReviewCardSection(
          title: '4. Selected Features & Amenities',
          icon: Icons.checklist_rtl,
          child: selectedAmenities.isNotEmpty
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: selectedAmenities.map((a) {
                    final clean = ParkingSpace.sanitizeAmenity(a);
                    if (clean.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Text(clean, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    );
                  }).toList(),
                )
              : const Text('No special amenities selected', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }

  Widget _buildReviewCardSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildReviewPricingRow(String vehicle, String hourly, String daily, String monthly, Color col) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(vehicle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: col)),
        Row(
          children: [
            Text(hourly, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(daily, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 8),
            Text(monthly, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryBadge(String label, String val, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.bold)),
          Text(val, style: TextStyle(fontSize: 13, color: col, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
