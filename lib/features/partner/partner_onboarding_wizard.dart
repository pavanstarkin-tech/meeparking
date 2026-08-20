import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/env_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../core/services/mapbox_geocoding_service.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/providers/app_providers.dart';
import 'partner_main_shell.dart';

class PartnerOnboardingWizard extends ConsumerStatefulWidget {
  final bool isAddingListingOnly;

  const PartnerOnboardingWizard({
    super.key,
    this.isAddingListingOnly = false,
  });

  @override
  ConsumerState<PartnerOnboardingWizard> createState() => _PartnerOnboardingWizardState();
}

class _PartnerOnboardingWizardState extends ConsumerState<PartnerOnboardingWizard> {
  int _currentStep = 0;

  // Step 1 Controllers: Contact Details
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  Uint8List? _pickedProfileBytes;
  bool _isUploadingProfilePhoto = false;

  void _pickAndUpdateProfilePhoto() async {
    final imageFile = await CloudinaryService.pickImage();
    if (imageFile == null) return;

    final bytes = await imageFile.readAsBytes();
    setState(() {
      _pickedProfileBytes = bytes;
      _isUploadingProfilePhoto = true;
    });

    final uploadedUrl = await CloudinaryService.uploadImage(imageFile);
    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      final user = ref.read(userProfileProvider);
      await FirebaseRtdbService.updateUserProfile(user.uid, {'photoUrl': uploadedUrl});
      ref.read(userProfileProvider.notifier).state = user.copyWith(photoUrl: uploadedUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: AppColors.greenSuccess,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isUploadingProfilePhoto = false);
    }
  }

  bool _isUploadingParkingPhoto = false;

  void _pickAndUploadParkingPhoto() async {
    final imageFile = await CloudinaryService.pickImage();
    if (imageFile == null) return;

    final bytes = await imageFile.readAsBytes();
    final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final photoIndex = _uploadedPhotos.length;

    // Immediately render preview locally via Base64 Data URI (100% safe on Web, iOS, Android)
    setState(() {
      _uploadedPhotos.add(dataUri);
      _isUploadingParkingPhoto = true;
    });

    try {
      final uploadedUrl = await CloudinaryService.uploadImage(imageFile);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty && mounted) {
        setState(() {
          if (photoIndex < _uploadedPhotos.length) {
            _uploadedPhotos[photoIndex] = uploadedUrl;
          }
        });
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploadingParkingPhoto = false);
      }
    }
  }

  // Step 2 Controllers: Map Location & Area Estimator
  final MapController _mapController = MapController();
  LatLng _selectedLocation = const LatLng(28.6139, 77.2090); // Initial map center
  LatLng? _myCurrentLocation; // Live User GPS Location
  final List<LatLng> _areaPolygonPoints = [];
  double _zoomLevel = 16.0;
  bool _isGeocoding = false;
  bool _isLocating = false;

  final _titleCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _carsCtrl = TextEditingController();
  final _bikesCtrl = TextEditingController();

  // Step 3: Parking Amenities (18 Items)
  final List<String> _availableAmenities = [
    'CCTV',
    'Fencing',
    'EV Charger',
    'Covered Parking',
    '24/7 Security',
    'Gated Entry',
    'Night Lighting',
    'Guard on Duty',
    'Two-Wheeler Parking',
    'Four-Wheeler Parking',
    'Accessible Parking',
    'Reserved Parking',
    'Fast EV Charging',
    'Car Wash',
    'Tyre Air / Inflation',
    'Battery Jump Start',
    'Digital Payment',
    'Valet Parking',
  ];
  final Set<String> _selectedAmenities = {}; // Do not pre-select any amenities by default

  // Step 4: Multi-Vehicle Category Pricing (2-Wheeler, 3-Wheeler, 4-Wheeler)
  // 2-Wheeler Pricing Controllers
  final _twoWheelerHourlyCtrl = TextEditingController();
  final _twoWheelerDailyCtrl = TextEditingController();
  final _twoWheelerWeeklyCtrl = TextEditingController();
  final _twoWheelerMonthlyCtrl = TextEditingController();

  // 3-Wheeler Pricing Controllers
  final _threeWheelerHourlyCtrl = TextEditingController();
  final _threeWheelerDailyCtrl = TextEditingController();
  final _threeWheelerWeeklyCtrl = TextEditingController();
  final _threeWheelerMonthlyCtrl = TextEditingController();

  // 4-Wheeler Pricing Controllers
  final _fourWheelerHourlyCtrl = TextEditingController();
  final _fourWheelerDailyCtrl = TextEditingController();
  final _fourWheelerWeeklyCtrl = TextEditingController();
  final _fourWheelerMonthlyCtrl = TextEditingController();

  final List<String> _uploadedPhotos = [];

  // Step 5: Weekly Availability & Business Hours
  TimeOfDay _openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);
  final Map<String, bool> _weeklyDays = {
    'Mon': true,
    'Tue': true,
    'Wed': true,
    'Thu': true,
    'Fri': true,
    'Sat': true,
    'Sun': true,
  };
  bool _is24x7 = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadAdminPricingDefaults();

    // If adding listing only, start on step 1 (Listing details & Location).
    // During partner initial onboarding, always start at Step 0 (Contact Details)!
    if (widget.isAddingListingOnly) {
      _currentStep = 1;
    } else {
      _currentStep = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = ref.read(userProfileProvider);
        if (_nameCtrl.text.isEmpty && user.name.isNotEmpty && user.name != 'Partner User' && user.name != 'User') {
          _nameCtrl.text = user.name;
        }
        if (_phoneCtrl.text.isEmpty && user.phone.isNotEmpty) {
          _phoneCtrl.text = user.phone;
        }
      });
    }
  }

  /// Load admin-configured pricing defaults and populate pricing inputs
  Future<void> _loadAdminPricingDefaults() async {
    try {
      final config = await FirebaseRtdbService.getAdminPricingConfig();
      if (!mounted) return;
      setState(() {
        final twoW = (config['twoWheeler'] as Map?) ?? {};
        final threeW = (config['threeWheeler'] as Map?) ?? {};
        final fourW = (config['fourWheeler'] as Map?) ?? {};

        if (_twoWheelerHourlyCtrl.text.isEmpty) _twoWheelerHourlyCtrl.text = (twoW['hourly'] ?? 20).toString().replaceAll('.0', '');
        if (_twoWheelerDailyCtrl.text.isEmpty) _twoWheelerDailyCtrl.text = (twoW['daily'] ?? 100).toString().replaceAll('.0', '');
        if (_twoWheelerWeeklyCtrl.text.isEmpty) _twoWheelerWeeklyCtrl.text = (twoW['weekly'] ?? 600).toString().replaceAll('.0', '');
        if (_twoWheelerMonthlyCtrl.text.isEmpty) _twoWheelerMonthlyCtrl.text = (twoW['monthly'] ?? 1800).toString().replaceAll('.0', '');

        if (_threeWheelerHourlyCtrl.text.isEmpty) _threeWheelerHourlyCtrl.text = (threeW['hourly'] ?? 30).toString().replaceAll('.0', '');
        if (_threeWheelerDailyCtrl.text.isEmpty) _threeWheelerDailyCtrl.text = (threeW['daily'] ?? 150).toString().replaceAll('.0', '');
        if (_threeWheelerWeeklyCtrl.text.isEmpty) _threeWheelerWeeklyCtrl.text = (threeW['weekly'] ?? 900).toString().replaceAll('.0', '');
        if (_threeWheelerMonthlyCtrl.text.isEmpty) _threeWheelerMonthlyCtrl.text = (threeW['monthly'] ?? 2700).toString().replaceAll('.0', '');

        if (_fourWheelerHourlyCtrl.text.isEmpty) _fourWheelerHourlyCtrl.text = (fourW['hourly'] ?? 60).toString().replaceAll('.0', '');
        if (_fourWheelerDailyCtrl.text.isEmpty) _fourWheelerDailyCtrl.text = (fourW['daily'] ?? 300).toString().replaceAll('.0', '');
        if (_fourWheelerWeeklyCtrl.text.isEmpty) _fourWheelerWeeklyCtrl.text = (fourW['weekly'] ?? 1500).toString().replaceAll('.0', '');
        if (_fourWheelerMonthlyCtrl.text.isEmpty) _fourWheelerMonthlyCtrl.text = (fourW['monthly'] ?? 4500).toString().replaceAll('.0', '');
      });
    } catch (_) {}
  }

  /// Request Live GPS Location and update Map position with resilient fallbacks
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      // 1. Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable GPS / Location services on your device.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      // 2. Check and request permission with Geolocator
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission was denied.')),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is permanently denied.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      // 3. Multi-tier position acquisition (High -> Medium/Low -> LastKnown)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
      } catch (_) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
        } catch (_) {
          position = await Geolocator.getLastKnownPosition();
        }
      }

      if (position != null) {
        final userLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _myCurrentLocation = userLatLng;
          _selectedLocation = userLatLng;
          _isLocating = false;
        });

        _mapController.move(userLatLng, 16.5);
        await _fetchReverseGeocode(userLatLng);
      } else {
        // Fallback to default/current map center if satellite fix is temporarily unavailable
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS signal weak. Centered on current map area.')),
          );
        }
        _mapController.move(_selectedLocation, 16.5);
        await _fetchReverseGeocode(_selectedLocation);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to acquire GPS signal. You can tap directly on the map to place your space.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Fetch Address & Auto-Generate Listing Title using Mapbox Reverse Geocoding API
  Future<void> _fetchReverseGeocode(LatLng location) async {
    setState(() => _isGeocoding = true);

    final res = await MapboxGeocodingService.reverseGeocode(
      location.latitude,
      location.longitude,
    );

    if (mounted) {
      setState(() {
        _addressCtrl.text = res.fullAddress;
        _titleCtrl.text = res.title;
        _isGeocoding = false;
      });
    }
  }

  /// Calculate exact geodesic area of marked polygon in square meters using Mapbox coordinates
  double _calculateGeodesicPolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    const double earthRadius = 6378137.0; // meters
    double totalArea = 0.0;
    final int count = points.length;

    for (int i = 0; i < count; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % count];

      final double lat1 = p1.latitudeInRad;
      final double lng1 = p1.longitudeInRad;
      final double lat2 = p2.latitudeInRad;
      final double lng2 = p2.longitudeInRad;

      totalArea += (lng2 - lng1) * (2.0 + math.sin(lat1) + math.sin(lat2));
    }

    totalArea = (totalArea * earthRadius * earthRadius / 2.0).abs();
    return totalArea;
  }

  void _updatePolygonAreaAndCapacity() {
    if (_areaPolygonPoints.length < 3) {
      _areaCtrl.clear();
      _carsCtrl.clear();
      _bikesCtrl.clear();
      return;
    }

    final double realAreaSqMeters = _calculateGeodesicPolygonArea(_areaPolygonPoints);
    _areaCtrl.text = realAreaSqMeters > 0 ? realAreaSqMeters.toStringAsFixed(1) : '';

    // Capacity calculation including driving aisle & maneuvering allowance:
    // ~16 m² per Car (4-Wheeler)
    // ~3.5 m² per Bike (2-Wheeler)
    final int estimatedCars = (realAreaSqMeters / 16.0).floor();
    final int estimatedBikes = (realAreaSqMeters / 3.5).floor();

    _carsCtrl.text = estimatedCars > 0 ? estimatedCars.toString() : '0';
    _bikesCtrl.text = estimatedBikes > 0 ? estimatedBikes.toString() : '0';
  }

  void _recalculateCapacityFromArea(String areaText) {
    final area = double.tryParse(areaText) ?? 0.0;
    if (area > 0) {
      final estimatedCars = (area / 16.0).floor();
      final estimatedBikes = (area / 3.5).floor();
      setState(() {
        _carsCtrl.text = estimatedCars.toString();
        _bikesCtrl.text = estimatedBikes.toString();
      });
    } else {
      setState(() {
        _carsCtrl.clear();
        _bikesCtrl.clear();
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.5).clamp(3.0, 19.0);
      _mapController.move(_selectedLocation, _zoomLevel);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.5).clamp(3.0, 19.0);
      _mapController.move(_selectedLocation, _zoomLevel);
    });
  }

  void _addPolygonPoint(LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _areaPolygonPoints.add(point);
      _updatePolygonAreaAndCapacity();
    });

    await _fetchReverseGeocode(point);
  }

  void _clearMarkedArea() {
    setState(() {
      _areaPolygonPoints.clear();
      _areaCtrl.clear();
      _carsCtrl.clear();
      _bikesCtrl.clear();
    });
  }

  Future<void> _selectTime(bool isOpening) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isOpening ? _openingTime : _closingTime,
    );
    if (selected != null) {
      setState(() {
        if (isOpening) {
          _openingTime = selected;
        } else {
          _closingTime = selected;
        }
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final user = ref.read(userProfileProvider);
    setState(() => _isSaving = true);

    try {
      final spaceId = 'space_${const Uuid().v4().substring(0, 8)}';

      final twoWheelerRates = VehicleCategoryRates(
        hourly: double.tryParse(_twoWheelerHourlyCtrl.text) ?? 20.0,
        daily: double.tryParse(_twoWheelerDailyCtrl.text) ?? 100.0,
        weekly: double.tryParse(_twoWheelerWeeklyCtrl.text) ?? 600.0,
        monthly: double.tryParse(_twoWheelerMonthlyCtrl.text) ?? 1800.0,
      );

      final threeWheelerRates = VehicleCategoryRates(
        hourly: double.tryParse(_threeWheelerHourlyCtrl.text) ?? 30.0,
        daily: double.tryParse(_threeWheelerDailyCtrl.text) ?? 150.0,
        weekly: double.tryParse(_threeWheelerWeeklyCtrl.text) ?? 900.0,
        monthly: double.tryParse(_threeWheelerMonthlyCtrl.text) ?? 2700.0,
      );

      final fourWheelerRates = VehicleCategoryRates(
        hourly: double.tryParse(_fourWheelerHourlyCtrl.text) ?? 60.0,
        daily: double.tryParse(_fourWheelerDailyCtrl.text) ?? 300.0,
        weekly: double.tryParse(_fourWheelerWeeklyCtrl.text) ?? 1500.0,
        monthly: double.tryParse(_fourWheelerMonthlyCtrl.text) ?? 4500.0,
      );

      final centerLat = _areaPolygonPoints.isNotEmpty
          ? _areaPolygonPoints.map((p) => p.latitude).reduce((a, b) => a + b) / _areaPolygonPoints.length
          : _selectedLocation.latitude;
      final centerLng = _areaPolygonPoints.isNotEmpty
          ? _areaPolygonPoints.map((p) => p.longitude).reduce((a, b) => a + b) / _areaPolygonPoints.length
          : _selectedLocation.longitude;

      final totalLandArea = double.tryParse(_areaCtrl.text) ?? 120.0;
      final maxCarsCount = int.tryParse(_carsCtrl.text) ?? 10;
      final maxBikesCount = int.tryParse(_bikesCtrl.text) ?? 20;

      final newSpace = ParkingSpace(
        id: spaceId,
        ownerId: user.uid,
        title: _titleCtrl.text.trim().isEmpty ? 'Private Parking Space' : _titleCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? 'Selected Location' : _addressCtrl.text.trim(),
        city: 'Current Area',
        lat: centerLat,
        lng: centerLng,
        images: _uploadedPhotos,
        description: 'Safe private parking spot registered by ${user.name}.',
        amenities: _selectedAmenities.map(ParkingSpace.sanitizeAmenity).where((a) => a.isNotEmpty).toList(),
        capacity: LandCapacity(
          totalLandSqMeters: totalLandArea,
          maxCars: maxCarsCount,
          maxBikes: maxBikesCount,
          currentCars: 0,
          currentBikes: 0,
        ),
        pricing: ParkingPricing(
          hourly: fourWheelerRates.hourly,
          daily: fourWheelerRates.daily,
          weekly: fourWheelerRates.weekly,
          monthly: fourWheelerRates.monthly,
          twoWheeler: twoWheelerRates,
          threeWheeler: threeWheelerRates,
          fourWheeler: fourWheelerRates,
        ),
        status: 'pending_approval',
        rating: 5.0,
        reviewCount: 0,
        distanceKm: 0.5,
        hasEvCharging: _selectedAmenities.contains('EV Charger') || _selectedAmenities.contains('Fast EV Charging'),
        polygonCoordinates: _areaPolygonPoints.length >= 3
            ? _areaPolygonPoints.map((p) => [p.latitude, p.longitude]).toList()
            : null,
      );

      // Persist to Firebase Realtime Database and send approval request to Admin
      await FirebaseRtdbService.addParkingSpace(newSpace, partnerDetails: {
        'name': _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : user.name,
        'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : user.phone,
        'email': user.email,
        'uid': user.uid,
      });

      // Mark partner profile as onboarding completed with full metadata
      await FirebaseRtdbService.updateUserProfile(user.uid, {
        'role': 'partner',
        'name': _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : user.name,
        'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : user.phone,
        'businessName': _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Partner Parking',
        'city': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Current Area',
        'capacity': maxCarsCount,
        'onboardingCompleted': true,
        'hasActiveListing': true,
      });

      ref.read(currentRoleProvider.notifier).state = 'partner';
    } catch (_) {
      // Continue gracefully even if offline
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PartnerMainShell()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.verified, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Parking Space submitted! Request sent to Admin for review & approval.'),
              ),
            ],
          ),
          backgroundColor: AppColors.greenSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && !widget.isAddingListingOnly) {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your full name.'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your contact phone number.'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      final user = ref.read(userProfileProvider);
      ref.read(userProfileProvider.notifier).state = user.copyWith(name: name, phone: phone);
      FirebaseRtdbService.updateUserProfile(user.uid, {
        'name': name,
        'phone': phone,
        'role': 'partner',
      });
    }

    if (_currentStep == 1) {
      final title = _titleCtrl.text.trim();
      final address = _addressCtrl.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter a name / title for your parking space.'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      if (address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter the street address / area.'),
            backgroundColor: AppColors.redError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    // Step 3 (0-indexed): Pricing & Spot Photos - Enforce Minimum 4 Images
    if (_currentStep == 3) {
      if (_uploadedPhotos.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please upload at least 4 photos of your parking space (${_uploadedPhotos.length}/4 uploaded).',
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
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (widget.isAddingListingOnly && _currentStep == 1) {
      Navigator.of(context).pop();
    } else if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            widget.isAddingListingOnly && _currentStep == 1 ? Icons.close : Icons.arrow_back,
            color: AppColors.textPrimaryLight,
          ),
          onPressed: _previousStep,
        ),
        title: Text(
          widget.isAddingListingOnly || _currentStep > 0
              ? 'Add New Listing ($_currentStep/4)'
              : 'Partner Setup (${_currentStep + 1}/5)',
          style: const TextStyle(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 5.0,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primary,
              minHeight: 4,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: _buildCurrentStepContent(),
              ),
            ),

            // Bottom CTA Navigation Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : Text(
                                _currentStep == 4 ? 'Save & Launch Listing' : 'Next Step',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Profile();
      case 1:
        return _buildStep2MapLocation();
      case 2:
        return _buildStep3Amenities();
      case 3:
        return _buildStep4PricingAndPhotos();
      case 4:
        return _buildStep5AvailabilityHours();
      default:
        return Container();
    }
  }

  // STEP 1: Profile Details
  Widget _buildStep1Profile() {
    final user = ref.watch(userProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Partner Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your contact details so vehicle owners can reach you for bookings.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 24),

        // Profile Photo Picker Avatar
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFF3E8FF),
                backgroundImage: _pickedProfileBytes != null
                    ? MemoryImage(_pickedProfileBytes!) as ImageProvider
                    : (user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null),
                child: (_pickedProfileBytes == null && user.photoUrl.isEmpty)
                    ? const Icon(Icons.person, size: 54, color: AppColors.primary)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingProfilePhoto ? null : _pickAndUpdateProfilePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isUploadingProfilePhoto
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Enter mobile number',
            prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  // STEP 2: Map Location & Reverse Geocoding Space Estimator
  Widget _buildStep2MapLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Map Location & Area Mark',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        const Text(
          'Position your spot on the map and mark the availability area. We reverse geocode your location automatically!',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 16),

        // Interactive Map Container with "Use My Current Location" & Mapbox Reverse Geocode
        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: _zoomLevel,
                    onTap: (_, point) => _addPolygonPoint(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: EnvConfig.mapboxTileUrl,
                      userAgentPackageName: 'com.meeparking.com',
                    ),
                    if (_areaPolygonPoints.isNotEmpty) ...[
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [..._areaPolygonPoints, _areaPolygonPoints.first],
                            strokeWidth: 3.0,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _areaPolygonPoints,
                            color: AppColors.primary.withOpacity(0.25),
                            borderColor: AppColors.primary,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    ],
                    MarkerLayer(
                      markers: [
                        // Live User Current Location Small Blue Dot
                        if (_myCurrentLocation != null)
                          Marker(
                            point: _myCurrentLocation!,
                            width: 20,
                            height: 20,
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.30),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withOpacity(0.40),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Marked Area Polygon Dots
                        if (_areaPolygonPoints.isNotEmpty)
                          ..._areaPolygonPoints.map(
                            (pt) => Marker(
                              point: pt,
                              width: 18,
                              height: 18,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.45),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (_myCurrentLocation == null)
                          // Single selected location dot (small blue dot)
                          Marker(
                            point: _selectedLocation,
                            width: 20,
                            height: 20,
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.30),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withOpacity(0.40),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Top "Use My Current Location" GPS Button Overlay
                Positioned(
                  top: 12,
                  left: 12,
                  child: ElevatedButton.icon(
                    onPressed: _isLocating ? null : _getCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.my_location, size: 16, color: Colors.white),
                    label: const Text(
                      'Use My Current Location',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                // Zoom Controls Overlay
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: _zoomIn,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.add, color: AppColors.textPrimaryLight),
                      ),
                      const SizedBox(height: 6),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: _zoomOut,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.remove, color: AppColors.textPrimaryLight),
                      ),
                    ],
                  ),
                ),



                if (_areaPolygonPoints.isNotEmpty)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: AppColors.redError.withOpacity(0.5), width: 1.2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.redError, size: 20),
                        tooltip: 'Clear Area',
                        onPressed: _clearMarkedArea,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Auto-Geocoded Listing Title Field
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Listing Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (_isGeocoding)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            hintText: 'Auto-populated from map location',
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),

        // Auto-Geocoded Full Address Field
        const Text('Full Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _addressCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Auto-populated via Mapbox Reverse Geocoding',
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),

        // DYNAMIC & EDITABLE CAPACITY ESTIMATOR SECTION
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.straighten, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Area & Capacity (Dynamically Calculated & Editable)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Total Area Input (Editable)
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text('Available Space (sq. m):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _areaCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: _recalculateCapacityFromArea,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        fillColor: AppColors.backgroundLight,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Max Cars Capacity (Editable)
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text('Max 4-Wheelers (Cars):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _carsCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        fillColor: AppColors.backgroundLight,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Max Bikes Capacity (Editable)
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text('Max 2-Wheelers (Bikes):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _bikesCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        fillColor: AppColors.backgroundLight,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getAmenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('cctv') || lower.contains('camera')) return Icons.videocam_outlined;
    if (lower.contains('ev') || lower.contains('charg')) return Icons.ev_station_outlined;
    if (lower.contains('cover') || lower.contains('roof')) return Icons.roofing_outlined;
    if (lower.contains('guard') || lower.contains('security')) return Icons.security_outlined;
    if (lower.contains('light')) return Icons.lightbulb_outline;
    if (lower.contains('valet')) return Icons.room_service_outlined;
    if (lower.contains('wash')) return Icons.local_car_wash_outlined;
    if (lower.contains('inflator') || lower.contains('air')) return Icons.air_outlined;
    if (lower.contains('wheelchair') || lower.contains('accessible')) return Icons.accessible_outlined;
    return Icons.local_parking_rounded;
  }

  // STEP 3: Multi-Category Amenities Selection
  Widget _buildStep3Amenities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Parking Amenities & Security',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select all features available at your facility (e.g. CCTV, EV Charging, Security Guard).',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 20),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableAmenities.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final amenity = _availableAmenities[index];
            final isSelected = _selectedAmenities.contains(amenity);

            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedAmenities.remove(amenity);
                  } else {
                    _selectedAmenities.add(amenity);
                  }
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getAmenityIcon(amenity),
                      color: isSelected ? AppColors.primary : Colors.grey.shade700,
                      size: 26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      amenity,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Custom Add Amenity Box
        StatefulBuilder(
          builder: (context, setCustomState) {
            final customCtrl = TextEditingController();
            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add custom feature (e.g. Tire Inflator)',
                      fillColor: Colors.white,
                      filled: true,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final txt = customCtrl.text.trim();
                    if (txt.isNotEmpty) {
                      setState(() {
                        if (!_availableAmenities.contains(txt)) {
                          _availableAmenities.add(txt);
                        }
                        _selectedAmenities.add(txt);
                      });
                      customCtrl.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // Selected Amenities Chips preview
        if (_selectedAmenities.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedAmenities.map((am) {
              return Chip(
                label: Text(am, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.primary.withOpacity(0.12),
                deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                onDeleted: () {
                  setState(() => _selectedAmenities.remove(am));
                },
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
      ],
    );
  }

  // STEP 4: Multi-Vehicle Category Pricing (2-Wheeler, 3-Wheeler, 4-Wheeler) & Spot Photos
  Widget _buildStep4PricingAndPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 4: Pricing & Spot Photos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        const Text(
          'Set separate pricing for each vehicle type and upload clear photos of your parking space.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 20),

        // 🚲 2-Wheeler Pricing Card
        _buildVehiclePricingCard(
          title: '🚲 2-Wheeler Pricing (Bike / Scooter)',
          hourlyCtrl: _twoWheelerHourlyCtrl,
          dailyCtrl: _twoWheelerDailyCtrl,
          weeklyCtrl: _twoWheelerWeeklyCtrl,
          monthlyCtrl: _twoWheelerMonthlyCtrl,
          hintHourly: 'e.g. 20',
          hintDaily: 'e.g. 100',
          hintWeekly: 'e.g. 600',
          hintMonthly: 'e.g. 1800',
        ),
        const SizedBox(height: 16),

        // 🛺 3-Wheeler Pricing Card
        _buildVehiclePricingCard(
          title: '🛺 3-Wheeler Pricing (Auto / E-Rickshaw)',
          hourlyCtrl: _threeWheelerHourlyCtrl,
          dailyCtrl: _threeWheelerDailyCtrl,
          weeklyCtrl: _threeWheelerWeeklyCtrl,
          monthlyCtrl: _threeWheelerMonthlyCtrl,
          hintHourly: 'e.g. 30',
          hintDaily: 'e.g. 150',
          hintWeekly: 'e.g. 900',
          hintMonthly: 'e.g. 2700',
        ),
        const SizedBox(height: 16),

        // 🚗 4-Wheeler Pricing Card
        _buildVehiclePricingCard(
          title: '🚗 4-Wheeler Pricing (Car / SUV)',
          hourlyCtrl: _fourWheelerHourlyCtrl,
          dailyCtrl: _fourWheelerDailyCtrl,
          weeklyCtrl: _fourWheelerWeeklyCtrl,
          monthlyCtrl: _fourWheelerMonthlyCtrl,
          hintHourly: 'e.g. 60',
          hintDaily: 'e.g. 300',
          hintWeekly: 'e.g. 1500',
          hintMonthly: 'e.g. 4500',
        ),
        const SizedBox(height: 24),

        // Photo Upload Section with Min 4 Requirement
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Upload Parking Spot Photos (Min 4)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
              '${_uploadedPhotos.length}/4 uploaded',
              style: TextStyle(
                fontSize: 12,
                color: _uploadedPhotos.length >= 4 ? AppColors.greenSuccess : AppColors.redError,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 105,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add photo button card
              GestureDetector(
                onTap: _isUploadingParkingPhoto ? null : _pickAndUploadParkingPhoto,
                child: Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploadingParkingPhoto)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else ...[
                        const Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
                        const SizedBox(height: 4),
                        const Text('Add Photo', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
              ),

              // Uploaded preview list
              ..._uploadedPhotos.asMap().entries.map(
                (entry) => _buildPhotoThumbnailItem(entry.value, entry.key),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoThumbnailItem(String imageSource, int index) {
    Widget imageWidget;
    if (imageSource.startsWith('data:image') || (!imageSource.startsWith('http') && imageSource.length > 100)) {
      try {
        final base64Str = imageSource.contains(',') ? imageSource.split(',').last : imageSource;
        final bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      } catch (_) {
        imageWidget = const Center(child: Icon(Icons.broken_image, color: Colors.grey));
      }
    } else if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      imageWidget = Image.network(
        imageSource,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      if (!kIsWeb) {
        final file = File(imageSource);
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      } else {
        imageWidget = const Center(
          child: Icon(Icons.image_outlined, color: AppColors.primary, size: 36),
        );
      }
    }

    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: imageWidget,
          ),
        ),
        Positioned(
          top: 6,
          right: 18,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _uploadedPhotos.removeAt(index);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehiclePricingCard({
    required String title,
    required TextEditingController hourlyCtrl,
    required TextEditingController dailyCtrl,
    required TextEditingController weeklyCtrl,
    required TextEditingController monthlyCtrl,
    required String hintHourly,
    required String hintDaily,
    required String hintWeekly,
    required String hintMonthly,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimaryLight)),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _buildPricingInput('Per Hour (₹)', hourlyCtrl, hintHourly),
              _buildPricingInput('Per Day (₹)', dailyCtrl, hintDaily),
              _buildPricingInput('Per Week (₹)', weeklyCtrl, hintWeekly),
              _buildPricingInput('Per Month (₹)', monthlyCtrl, hintMonthly),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingInput(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            fillColor: AppColors.backgroundLight,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  // STEP 5: Business Hours & Weekly Operating Timings
  Widget _buildStep5AvailabilityHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 5: Weekly Business Hours',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        const Text(
          'Define operating hours and days your parking space is open to customers.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 20),

        // 24x7 Switch Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('24 Hours / 7 Days Open', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Always available for instant booking', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                ],
              ),
              Switch(
                value: _is24x7,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _is24x7 = val;
                    if (val) {
                      _weeklyDays.updateAll((key, value) => true);
                    }
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (!_is24x7) ...[
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(true),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Opening Time', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                        const SizedBox(height: 6),
                        Text(
                          _openingTime.format(context),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(false),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Closing Time', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                        const SizedBox(height: 6),
                        Text(
                          _closingTime.format(context),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        const Text('Operating Days', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weeklyDays.keys.map((day) {
            final isOpen = _weeklyDays[day]!;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _weeklyDays[day] = !isOpen;
                });
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isOpen ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isOpen ? AppColors.primary : Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: isOpen ? Colors.white : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
