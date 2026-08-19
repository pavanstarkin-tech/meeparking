import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/config/env_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../core/services/mapbox_geocoding_service.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/slot_space_slider.dart';
import '../parking/parking_details_screen.dart';

class SearchParkingScreen extends ConsumerStatefulWidget {
  const SearchParkingScreen({super.key});

  @override
  ConsumerState<SearchParkingScreen> createState() => _SearchParkingScreenState();
}

class _SearchParkingScreenState extends ConsumerState<SearchParkingScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  List<PlaceSearchResult> _searchSuggestions = [];
  bool _isSearching = false;
  bool _isLocating = false;
  bool _isSatelliteMode = false;
  LatLng? _currentPosition;
  LatLng _mapCenter = const LatLng(28.6315, 77.2167); // Default fallback area

  @override
  void initState() {
    super.initState();
    _locateUserAndCenterMap();
  }

  Future<void> _locateUserAndCenterMap({bool showFeedback = false}) async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS location services on your device.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (showFeedback && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission was denied.')),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is permanently denied in settings.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      // 1. Instantly center on cached last known GPS location (0ms startup latency)
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        final lastLatLng = LatLng(lastPos.latitude, lastPos.longitude);
        setState(() {
          _currentPosition = lastLatLng;
          _mapCenter = lastLatLng;
        });
        _mapController.move(lastLatLng, 16.2);
      }

      // 2. Fetch fresh high accuracy live location and refine center
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final liveLatLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = liveLatLng;
          _mapCenter = liveLatLng;
          _isLocating = false;
        });
        _mapController.move(liveLatLng, 16.2);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _onSearchQueryChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await MapboxGeocodingService.searchPlaces(query);
    if (mounted) {
      setState(() {
        _searchSuggestions = results;
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(PlaceSearchResult res) {
    FocusScope.of(context).unfocus();
    final newLocation = LatLng(res.lat, res.lng);
    setState(() {
      _mapCenter = newLocation;
      _searchCtrl.text = res.placeName;
      _searchSuggestions = [];
    });
    _mapController.move(newLocation, 16.2);
  }

  @override
  Widget build(BuildContext context) {
    final evFilter = ref.watch(evFilterProvider);
    final coveredFilter = ref.watch(coveredFilterProvider);
    final cctvFilter = ref.watch(cctvFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: StreamBuilder<List<ParkingSpace>>(
        stream: FirebaseRtdbService.streamParkingSpaces(),
        builder: (context, snapshot) {
          final rawSpaces = snapshot.data ?? [];
          final allSpaces = rawSpaces.where((s) => s.polygonCoordinates != null && s.polygonCoordinates!.length >= 3).toList();
          var filteredSpaces = allSpaces;
          if (evFilter) {
            filteredSpaces = filteredSpaces.where((s) => s.hasEvCharging || s.isEvChargingAvailable).toList();
          }
          if (coveredFilter) {
            filteredSpaces = filteredSpaces.where((s) => s.amenities.contains('Covered Parking') || s.amenities.contains('Covered')).toList();
          }
          if (cctvFilter) {
            filteredSpaces = filteredSpaces.where((s) => s.amenities.contains('CCTV') || s.amenities.contains('CCTV Surveillance')).toList();
          }

          final polygons = <Polygon>[];
          final polylines = <Polyline>[];
          for (final space in filteredSpaces) {
            final poly = _getParkingPolygon(space);
            if (poly != null) {
              polygons.add(poly);
              if (space.polygonCoordinates != null && space.polygonCoordinates!.length >= 3) {
                polylines.add(
                  Polyline(
                    points: [
                      ...space.polygonCoordinates!.map((c) => LatLng(c[0], c[1])),
                      LatLng(space.polygonCoordinates!.first[0], space.polygonCoordinates!.first[1]),
                    ],
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                );
              }
            }
          }

          final markers = <Marker>[
            ...filteredSpaces.asMap().entries.map((entry) {
              return _buildMapMarker(entry.value, entry.key, filteredSpaces.length);
            }),
            if (_currentPosition != null)
              Marker(
                point: _currentPosition!,
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x661A73E8),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
          ];

          return Stack(
            children: [
              // Flutter Map View
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: 16.2,
                ),
                children: [
                  TileLayer(
                    urlTemplate: _isSatelliteMode
                        ? EnvConfig.mapboxSatelliteTileUrl
                        : EnvConfig.mapboxTileUrl,
                    userAgentPackageName: 'com.meeparking.com',
                  ),
                  PolygonLayer(polygons: polygons),
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                ],
              ),

          // Top Header & Mapbox Places Search Bar
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search place via Mapbox...',
                                hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
                                border: InputBorder.none,
                                suffixIcon: _isSearching
                                    ? const UnconstrainedBox(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        ),
                                      )
                                    : (_searchCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _searchCtrl.clear();
                                              _onSearchQueryChanged('');
                                            },
                                          )
                                        : null),
                              ),
                              onChanged: _onSearchQueryChanged,
                            ),
                          ),
                        ],
                      ),
                      if (_searchSuggestions.isNotEmpty) ...[
                        const Divider(height: 1),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchSuggestions.length,
                            itemBuilder: (context, idx) {
                              final item = _searchSuggestions[idx];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                                title: Text(item.placeName, style: const TextStyle(fontSize: 13)),
                                onTap: () => _selectSearchResult(item),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Horizontal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('EV Charger', evFilter, () {
                        ref.read(evFilterProvider.notifier).state = !evFilter;
                      }),
                      _buildFilterChip('Covered', coveredFilter, () {
                        ref.read(coveredFilterProvider.notifier).state = !coveredFilter;
                      }),
                      _buildFilterChip('CCTV', cctvFilter, () {
                        ref.read(cctvFilterProvider.notifier).state = !cctvFilter;
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Satellite / 3D Aerial View Toggle Button
          Positioned(
            right: 16,
            bottom: 195,
            child: FloatingActionButton(
              heroTag: 'map_layer_toggle_btn',
              onPressed: () {
                setState(() => _isSatelliteMode = !_isSatelliteMode);
              },
              backgroundColor: _isSatelliteMode ? AppColors.primary : Colors.white,
              elevation: 4,
              child: Icon(
                _isSatelliteMode ? Icons.layers : Icons.layers_outlined,
                color: _isSatelliteMode ? Colors.white : AppColors.primary,
                size: 24,
              ),
            ),
          ),

          // GPS Relocate Floating Action Button
          Positioned(
            right: 16,
            bottom: 135,
            child: FloatingActionButton(
              heroTag: 'relocate_gps_btn',
              onPressed: () => _locateUserAndCenterMap(showFeedback: true),
              backgroundColor: Colors.white,
              elevation: 4,
              child: _isLocating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                    )
                  : const Icon(Icons.my_location, color: AppColors.primary, size: 24),
            ),
          ),

          // Floating Property Preview Cards Carousel at bottom
          if (filteredSpaces.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: SizedBox(
                height: 105,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: filteredSpaces.length,
                  itemBuilder: (context, index) {
                    final space = filteredSpaces[index];
                    return _buildFloatingParkingCard(space);
                  },
                ),
              ),
            ),
        ],
      );
    },
  ),
);
  }

  Polygon? _getParkingPolygon(ParkingSpace space) {
    if (space.polygonCoordinates != null && space.polygonCoordinates!.length >= 3) {
      final points = space.polygonCoordinates!
          .map((coord) => LatLng(coord[0], coord[1]))
          .toList();
      return Polygon(
        points: points,
        color: AppColors.primary.withOpacity(0.22),
        borderColor: AppColors.primary,
        borderStrokeWidth: 2.5,
        isFilled: true,
      );
    }
    return null;
  }

  double _calculatePolygonOrientationAngle(List<List<double>> coords) {
    if (coords.length < 2) return 0.0;
    double maxDistSq = -1.0;
    double bestAngle = 0.0;

    for (int i = 0; i < coords.length; i++) {
      final p1 = coords[i];
      final p2 = coords[(i + 1) % coords.length];

      final latRad = p1[0] * (math.pi / 180.0);
      final dx = (p2[1] - p1[1]) * math.cos(latRad);
      final dy = -(p2[0] - p1[0]);

      final distSq = dx * dx + dy * dy;
      if (distSq > maxDistSq) {
        maxDistSq = distSq;
        bestAngle = math.atan2(dy, dx);
      }
    }

    // Keep text readable (never inverted / upside-down)
    while (bestAngle > math.pi / 2) {
      bestAngle -= math.pi;
    }
    while (bestAngle < -math.pi / 2) {
      bestAngle += math.pi;
    }
    return bestAngle;
  }

  Marker _buildMapMarker(ParkingSpace space, int index, int total) {
    final List<double> prices = [
      space.pricing.twoWheeler.hourly,
      space.pricing.fourWheeler.hourly,
    ].where((p) => p > 0).toList();

    final int minPrice = prices.isNotEmpty
        ? prices.reduce((a, b) => a < b ? a : b).toInt()
        : 20;

    LatLng point = LatLng(space.lat, space.lng);
    double rotationAngle = 0.0;

    if (space.polygonCoordinates != null && space.polygonCoordinates!.length >= 3) {
      double sumLat = 0;
      double sumLng = 0;
      for (final pt in space.polygonCoordinates!) {
        sumLat += pt[0];
        sumLng += pt[1];
      }
      point = LatLng(
        sumLat / space.polygonCoordinates!.length,
        sumLng / space.polygonCoordinates!.length,
      );
      rotationAngle = _calculatePolygonOrientationAngle(space.polygonCoordinates!);
    }

    return Marker(
      point: point,
      alignment: Alignment.center,
      width: 90,
      height: 90,
      child: GestureDetector(
        onTap: () {
          _mapController.move(point, 16.5);
          _showPropertyDetailsBottomSheet(context, space);
        },
        child: Center(
          child: Transform.rotate(
            angle: rotationAngle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'P',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '₹$minPrice/hr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingParkingCard(ParkingSpace space) {
    final List<double> prices = [
      space.pricing.twoWheeler.hourly,
      space.pricing.fourWheeler.hourly,
    ].where((p) => p > 0).toList();

    final int minPrice = prices.isNotEmpty
        ? prices.reduce((a, b) => a < b ? a : b).toInt()
        : 20;

    return GestureDetector(
      onTap: () {
        _mapController.move(LatLng(space.lat, space.lng), 16.0);
        _showPropertyDetailsBottomSheet(context, space);
      },
      child: Container(
        width: 270,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildSafeImage(
                space.images.isNotEmpty ? space.images.first : '',
                width: 70,
                height: 70,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    space.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    space.address,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 13),
                          const SizedBox(width: 2),
                          Text(
                            '${space.rating}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        '₹$minPrice/hr',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPropertyDetailsBottomSheet(BuildContext context, ParkingSpace space) {
    final List<double> prices = [
      space.pricing.twoWheeler.hourly,
      space.pricing.fourWheeler.hourly,
    ].where((p) => p > 0).toList();

    final int minPrice = prices.isNotEmpty
        ? prices.reduce((a, b) => a < b ? a : b).toInt()
        : 20;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.78,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        SlotSpaceSlider(
                          images: space.images,
                          height: 170,
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${space.rating}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Starts @ ₹$minPrice/hr',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    space.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${space.address}, ${space.city}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (space.amenities.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: space.amenities.map((amenity) {
                        final clean = ParkingSpace.sanitizeAmenity(amenity);
                        if (clean.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            clean,
                            style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ParkingDetailsScreen(spaceId: space.id),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Slot Details & Book Spot',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSafeImage(String imageSource, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (imageSource.startsWith('data:image') || (!imageSource.startsWith('http') && imageSource.length > 100)) {
      try {
        final base64Str = imageSource.contains(',') ? imageSource.split(',').last : imageSource;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            width: width,
            height: height,
            color: Colors.purple.shade50,
            child: const Icon(Icons.local_parking, color: AppColors.primary, size: 32),
          ),
        );
      } catch (_) {
        return Container(
          width: width,
          height: height,
          color: Colors.purple.shade50,
          child: const Icon(Icons.local_parking, color: AppColors.primary, size: 32),
        );
      }
    }

    if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      return Image.network(
        imageSource,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.purple.shade50,
          child: const Icon(Icons.local_parking, color: AppColors.primary, size: 32),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      color: Colors.purple.shade50,
      child: const Icon(Icons.local_parking, color: AppColors.primary, size: 32),
    );
  }
}
