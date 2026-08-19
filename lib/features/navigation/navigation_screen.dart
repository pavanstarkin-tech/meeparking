import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../../core/config/env_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/mapbox_geocoding_service.dart';
import '../../core/services/navigation_route_service.dart';
import '../../core/services/parking_service.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/parking_space.dart';

class NavigationScreen extends StatefulWidget {
  final Booking booking;

  const NavigationScreen({super.key, required this.booking});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePoints = [];
  List<RouteStep> _routeSteps = [];
  int _currentStepIndex = 0;
  double _distanceKm = 0.0;
  int _estimatedMinutes = 0;
  bool _isLoading = true;
  bool _isNavigating = false; // False = Route Preview, True = Active Google Navigation
  bool _isFollowingUser = true;
  double _userHeading = 0.0; // Dynamic gyro / GPS bearing in degrees
  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<CompassEvent>? _compassStreamSub;
  ParkingSpace? _parkingSpace;

  @override
  void initState() {
    super.initState();
    _initRealNavigation();
    _startCompassListener();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _compassStreamSub?.cancel();
    super.dispose();
  }

  /// Real-time 60fps hardware Gyroscope / Magnetometer / Compass sensor listener
  void _startCompassListener() {
    _compassStreamSub?.cancel();
    _compassStreamSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      final rawHeading = event.heading;
      if (rawHeading != null && !rawHeading.isNaN) {
        final double normalized = (rawHeading % 360 + 360) % 360;

        // Calculate shortest angular difference to prevent 360->0 boundary snapping
        double diff = normalized - (_userHeading % 360);
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;

        // Low-pass filter for smooth, jitter-free real-time orientation
        setState(() {
          _userHeading += diff * 0.40;
        });
      }
    });
  }

  Future<void> _initRealNavigation() async {
    setState(() => _isLoading = true);

    // 1. Resolve real parking destination coordinates
    await _resolveDestinationCoordinates();

    // 2. Resolve user current GPS location
    await _resolveUserLocation();

    // 3. Fetch real road network driving route
    if (_userLocation != null && _destinationLocation != null) {
      await _calculateRoadRoute(_userLocation!, _destinationLocation!);
    }

    // 4. Start live GPS tracking stream
    _startLiveGpsTracking();

    if (mounted) {
      setState(() => _isLoading = false);
      if (_userLocation != null) {
        _mapController.move(_userLocation!, 17.3);
      }
    }
  }

  Future<void> _resolveDestinationCoordinates() async {
    try {
      final space = await ParkingService.getSpaceById(widget.booking.spaceId);
      if (space != null) {
        _parkingSpace = space;
        if (space.polygonCoordinates != null && space.polygonCoordinates!.length >= 3) {
          double sumLat = 0;
          double sumLng = 0;
          for (final pt in space.polygonCoordinates!) {
            sumLat += pt[0];
            sumLng += pt[1];
          }
          _destinationLocation = LatLng(
            sumLat / space.polygonCoordinates!.length,
            sumLng / space.polygonCoordinates!.length,
          );
        } else if (space.lat != 0.0 && space.lng != 0.0) {
          _destinationLocation = LatLng(space.lat, space.lng);
        }
      }
    } catch (_) {}

    // Fallback: Geocode space address if coordinates weren't found
    if (_destinationLocation == null || (_destinationLocation!.latitude == 0 && _destinationLocation!.longitude == 0)) {
      try {
        final query = '${widget.booking.spaceAddress}, ${widget.booking.spaceTitle}';
        final results = await MapboxGeocodingService.searchPlaces(query);
        if (results.isNotEmpty) {
          _destinationLocation = LatLng(results.first.lat, results.first.lng);
        }
      } catch (_) {}
    }

    // Final fallback (Rajahmundry coordinates)
    _destinationLocation ??= const LatLng(17.0005, 81.8040);
  }

  Future<void> _resolveUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return;
        }
      }

      // 1. Immediately center on cached last known GPS position for zero-latency startup
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        final lastLatLng = LatLng(lastPos.latitude, lastPos.longitude);
        setState(() {
          _userLocation = lastLatLng;
        });
        _mapController.move(lastLatLng, 17.3);
      }

      // 2. Obtain fresh high-accuracy live GPS fix and center map
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );

      final freshLatLng = LatLng(pos.latitude, pos.longitude);
      double heading = _userHeading;
      if (pos.heading != 0.0 && !pos.heading.isNaN) {
        heading = pos.heading;
      }

      if (mounted) {
        setState(() {
          _userLocation = freshLatLng;
          _userHeading = heading;
        });
        _mapController.move(freshLatLng, 17.3);
      }
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  Future<void> _calculateRoadRoute(LatLng start, LatLng destination) async {
    final routeResult = await NavigationRouteService.fetchDrivingRoute(
      start: start,
      destination: destination,
    );

    if (routeResult != null && routeResult.points.isNotEmpty) {
      if (mounted) {
        setState(() {
          _routePoints = routeResult.points;
          _routeSteps = routeResult.steps;
          _distanceKm = routeResult.distanceKm;
          _estimatedMinutes = routeResult.durationMinutes;
          _currentStepIndex = 0;
          if (_routePoints.length >= 2) {
            _userHeading = _calculateBearing(_routePoints[0], _routePoints[1]);
          }
        });

        if (!_isNavigating) {
          if (_userLocation != null) {
            _mapController.move(_userLocation!, 17.3);
          } else {
            _fitMapBounds();
          }
        }
      }
    } else {
      // Direct haversine fallback line if routing service is offline
      final distMeters = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        destination.latitude,
        destination.longitude,
      );
      final distKm = distMeters / 1000.0;
      if (mounted) {
        setState(() {
          _routePoints = [start, destination];
          _distanceKm = double.parse(distKm.toStringAsFixed(1));
          _estimatedMinutes = (distKm * 3.0).ceil().clamp(1, 999);
        });
        if (!_isNavigating) {
          if (_userLocation != null) {
            _mapController.move(_userLocation!, 17.3);
          } else {
            _fitMapBounds();
          }
        }
      }
    }
  }

  void _fitMapBounds() {
    if (_routePoints.isEmpty) {
      if (_userLocation != null) {
        _mapController.move(_userLocation!, 17.0);
      }
      return;
    }

    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (final p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 16.0);
  }

  /// Calculates a forward-offset camera center so the user navigation puck sits
  /// near the lower-middle portion of the screen (exactly like Google Maps Navigation).
  LatLng _getNavigationCameraCenter(LatLng userPos, {double? zoom}) {
    final z = zoom ?? (tryGetMapZoom() ?? 18.8);
    // At zoom 18.8, 0.00028 deg latitude places the puck ~68% down the screen
    final scale = math.pow(2.0, 18.8 - z);
    final latOffset = 0.00028 * scale;
    return LatLng(userPos.latitude + latOffset, userPos.longitude);
  }

  double? tryGetMapZoom() {
    try {
      return _mapController.camera.zoom;
    } catch (_) {
      return null;
    }
  }

  void _startNavigationMode() {
    setState(() {
      _isNavigating = true;
      _isFollowingUser = true;
    });

    _recenterOnUser(zoom: 18.8);
  }

  void _recenterOnUser({double? zoom}) {
    if (_userLocation != null) {
      setState(() => _isFollowingUser = true);
      final targetZoom = zoom ?? 18.8;
      final targetCenter = _getNavigationCameraCenter(_userLocation!, zoom: targetZoom);
      _mapController.move(targetCenter, targetZoom);
    }
  }

  void _zoomIn() {
    final currentZoom = tryGetMapZoom() ?? 18.8;
    final currentCenter = _mapController.camera.center;
    _mapController.move(currentCenter, (currentZoom + 0.7).clamp(3.0, 20.0));
  }

  void _zoomOut() {
    final currentZoom = tryGetMapZoom() ?? 18.8;
    final currentCenter = _mapController.camera.center;
    _mapController.move(currentCenter, (currentZoom - 0.7).clamp(3.0, 20.0));
  }

  void _startLiveGpsTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // Update every 2 meters for smooth gyro heading
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      final newLatLng = LatLng(pos.latitude, pos.longitude);

      double newHeading = _userHeading;
      if (pos.heading != 0.0 && !pos.heading.isNaN) {
        newHeading = pos.heading;
      } else if (_userLocation != null) {
        final dMeters = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          newLatLng.latitude,
          newLatLng.longitude,
        );
        if (dMeters >= 1.0) {
          newHeading = _calculateBearing(_userLocation!, newLatLng);
        }
      }

      setState(() {
        _userLocation = newLatLng;
        _userHeading = newHeading;

        // Recalculate remaining distance to destination
        if (_destinationLocation != null) {
          final remainingMeters = Geolocator.distanceBetween(
            newLatLng.latitude,
            newLatLng.longitude,
            _destinationLocation!.latitude,
            _destinationLocation!.longitude,
          );
          _distanceKm = double.parse((remainingMeters / 1000.0).toStringAsFixed(1));
          _estimatedMinutes = (_distanceKm * 2.8).ceil().clamp(1, 999);
        }
      });

      if (_isNavigating && _isFollowingUser) {
        final currentZoom = (tryGetMapZoom() ?? 18.8).clamp(18.0, 20.0);
        final targetCenter = _getNavigationCameraCenter(newLatLng, zoom: currentZoom);
        _mapController.move(targetCenter, currentZoom);
      }
    });
  }

  String _formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).toInt()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatStepDistance(double meters) {
    if (meters <= 25) return 'Now';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
  }

  String _getArrivalTime() {
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: _estimatedMinutes));
    final hour = arrival.hour > 12 ? arrival.hour - 12 : (arrival.hour == 0 ? 12 : arrival.hour);
    final minute = arrival.minute.toString().padLeft(2, '0');
    final period = arrival.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final userPos = _userLocation ?? const LatLng(17.0005, 81.8040);
    final destPos = _destinationLocation ?? const LatLng(17.0005, 81.8040);
    final initialMapCenter = _isNavigating ? _getNavigationCameraCenter(userPos, zoom: 18.8) : userPos;

    final currentStep = (_routeSteps.isNotEmpty && _currentStepIndex < _routeSteps.length)
        ? _routeSteps[_currentStepIndex]
        : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // 1. Full-Screen Dark Navigation Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialMapCenter,
              initialZoom: _isNavigating ? 18.8 : 17.3,
              maxZoom: 20.0,
              minZoom: 3.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _isFollowingUser) {
                  setState(() => _isFollowingUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: EnvConfig.mapboxDarkTileUrl,
                userAgentPackageName: 'com.meeparking.com',
                maxZoom: 20.0,
                maxNativeZoom: 18,
              ),

              // Road Route Polyline Layer
              if (_routePoints.isNotEmpty) ...[
                // Outer glow border line
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 9.0,
                      color: const Color(0xFF4C1D95),
                    ),
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6.0,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ],

              // Destination Slot Polygon
              if (_parkingSpace?.polygonCoordinates != null && _parkingSpace!.polygonCoordinates!.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _parkingSpace!.polygonCoordinates!
                          .map((pt) => LatLng(pt[0], pt[1]))
                          .toList(),
                      color: AppColors.primary.withOpacity(0.4),
                      borderColor: const Color(0xFFA78BFA),
                      borderStrokeWidth: 2.5,
                      isFilled: true,
                    ),
                  ],
                ),

              // Interactive Markers Layer
              MarkerLayer(
                markers: [
                  // User Current Position / Google Maps Dynamic Real-Time Sensor-Tilted Pointer
                  Marker(
                    point: userPos,
                    width: _isNavigating ? 84 : 58,
                    height: _isNavigating ? 84 : 58,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: _userHeading * (math.pi / 180.0)),
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.easeOutQuad,
                      builder: (context, angle, child) {
                        return Transform.rotate(
                          angle: angle,
                          child: child,
                        );
                      },
                      child: _isNavigating
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                // Dynamic Forward Vision Beam / Accuracy Cone
                                Positioned(
                                  top: 0,
                                  child: CustomPaint(
                                    size: const Size(72, 44),
                                    painter: _GoogleMapsNavigationConePainter(
                                      color: const Color(0xFF60A5FA),
                                    ),
                                  ),
                                ),
                                // 3D Gyro Perspective Tilted Navigation Chevron
                                Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.002) // Perspective depth
                                    ..rotateX(0.42), // 3D Pitch tilt like Google Maps
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1D4ED8),
                                      border: Border.all(color: Colors.white, width: 3.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF1D4ED8).withOpacity(0.6),
                                          blurRadius: 14,
                                          spreadRadius: 3,
                                          offset: const Offset(0, 4),
                                        ),
                                        const BoxShadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.navigation_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                // Forward Beam in Preview Mode
                                Positioned(
                                  top: 2,
                                  child: CustomPaint(
                                    size: const Size(48, 30),
                                    painter: _GoogleMapsNavigationConePainter(
                                      color: const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF2563EB),
                                    border: Border.all(color: Colors.white, width: 3.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.navigation_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Destination Parking Space Marker
                  Marker(
                    point: destPos,
                    width: 52,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Turn-by-Turn Instruction Banner (Visible only during active navigation)
          if (_isNavigating)
            SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2417),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Maneuver Turn Arrow Icon Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        currentStep?.icon ?? Icons.navigation_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Prominent Turn / Diversion Distance
                          Text(
                            'In ${_formatStepDistance(currentStep?.distanceMeters ?? (_distanceKm * 1000))}',
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Maneuver Instruction
                          Text(
                            currentStep?.instruction ?? 'Drive to ${widget.booking.spaceTitle}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),

                          // Destination / Street Name
                          Text(
                            widget.booking.spaceAddress,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
                      tooltip: 'Recalculate Route',
                      onPressed: () {
                        if (_userLocation != null && _destinationLocation != null) {
                          _calculateRoadRoute(_userLocation!, _destinationLocation!);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

          // 3. Floating Re-Center Button (Google Maps Style Bottom-Left Pill)
          if (_isNavigating && !_isFollowingUser)
            Positioned(
              left: 20,
              bottom: 125,
              child: GestureDetector(
                onTap: () => _recenterOnUser(zoom: 18.8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B2E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFA78BFA), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigation_rounded, color: Color(0xFFA78BFA), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Re-center',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Floating Action Controls (Google Maps Zoom +/-, Overview & Recenter)
          Positioned(
            right: 16,
            bottom: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In/Out Floating Pill
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        tooltip: 'Zoom in',
                        onPressed: _zoomIn,
                      ),
                      Container(height: 1, width: 28, color: Colors.white12),
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                        tooltip: 'Zoom out',
                        onPressed: _zoomOut,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Route Overview Button
                FloatingActionButton.small(
                  heroTag: 'fit_route_btn',
                  backgroundColor: const Color(0xFF1E1B2E),
                  onPressed: () {
                    setState(() => _isFollowingUser = false);
                    _fitMapBounds();
                  },
                  tooltip: 'Route Overview',
                  child: const Icon(Icons.route_rounded, color: Colors.white),
                ),
                const SizedBox(height: 10),

                // Re-center on My GPS Location Button
                FloatingActionButton.small(
                  heroTag: 'my_loc_btn',
                  backgroundColor: _isFollowingUser ? AppColors.primary : const Color(0xFF1E1B2E),
                  onPressed: () => _recenterOnUser(zoom: 18.0),
                  tooltip: 'Center on My Location',
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),

          // 5. Bottom Navigation Control Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF181524),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 24,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: _isNavigating
                    ? // Active Navigation Mode Bottom HUD (Google Maps Style)
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${_estimatedMinutes.clamp(1, 999)} min',
                                      style: const TextStyle(
                                        color: Color(0xFF34D399),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '(${_formatDistance(_distanceKm)})',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.flag_outlined, color: Colors.white54, size: 13),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'ETA ${_getArrivalTime()} • Parking Spot',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.map_outlined, color: Colors.white70),
                                tooltip: 'Route Overview',
                                onPressed: () {
                                  setState(() => _isFollowingUser = false);
                                  _fitMapBounds();
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.redError,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                                child: const Text(
                                  'Exit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : // Route Preview Mode Bottom HUD (Google Maps Style "Start" Button)
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${_estimatedMinutes.clamp(1, 999)} min',
                                      style: const TextStyle(
                                        color: Color(0xFF34D399),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '(${_formatDistance(_distanceKm)})',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Fastest route via ${widget.booking.spaceTitle}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _startNavigationMode,
                            icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                            label: const Text(
                              'Start',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              elevation: 6,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // 6. Top Left Back Button (Preview Mode Only)
          if (!_isNavigating)
            Positioned(
              top: 14,
              left: 16,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

          // 7. Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Calculating real road route...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Calculates geodesic forward bearing in degrees between two GPS coordinates
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180.0);
    final lon1 = start.longitude * (math.pi / 180.0);
    final lat2 = end.latitude * (math.pi / 180.0);
    final lon2 = end.longitude * (math.pi / 180.0);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    return (radians * (180.0 / math.pi) + 360.0) % 360.0;
  }
}

/// Custom painter for Google Maps style directional forward vision/radar accuracy cone
class _GoogleMapsNavigationConePainter extends CustomPainter {
  final Color color;
  _GoogleMapsNavigationConePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.2),
        radius: 0.85,
        colors: [
          color.withOpacity(0.50),
          color.withOpacity(0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.55)
      ..lineTo(size.width * 0.06, 0)
      ..arcToPoint(
        Offset(size.width * 0.94, 0),
        radius: Radius.circular(size.width * 0.7),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
