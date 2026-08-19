import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

class GeocodingResult {
  final String title;
  final String fullAddress;
  final String city;

  GeocodingResult({
    required this.title,
    required this.fullAddress,
    required this.city,
  });
}

class PlaceSearchResult {
  final String placeName;
  final String address;
  final double lat;
  final double lng;

  PlaceSearchResult({
    required this.placeName,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class MapboxGeocodingService {
  /// Search places via Mapbox Places API
  static Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    final token = EnvConfig.mapboxAccessToken;
    if (token.isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json?access_token=$token&autocomplete=true&limit=5',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null) {
          return features.map((f) {
            final center = f['center'] as List?;
            final lng = (center != null && center.isNotEmpty) ? (center[0] as num).toDouble() : 0.0;
            final lat = (center != null && center.length > 1) ? (center[1] as num).toDouble() : 0.0;
            return PlaceSearchResult(
              placeName: f['text'] as String? ?? query,
              address: f['place_name'] as String? ?? query,
              lat: lat,
              lng: lng,
            );
          }).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Reverse geocode LatLng coordinates using Mapbox API (with Nominatim fallback)
  static Future<GeocodingResult> reverseGeocode(double lat, double lng) async {
    final token = EnvConfig.mapboxAccessToken;

    // Try Mapbox Geocoding API if token is present
    if (token.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$token&types=poi,address,neighborhood,locality,place',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final first = features.first;
            final fullAddress = first['place_name'] as String? ?? '';
            final placeText = first['text'] as String? ?? 'Parking Area';

            // Extract context for city name if available
            String city = 'Nearby Location';
            final context = first['context'] as List?;
            if (context != null) {
              for (final item in context) {
                final id = item['id'] as String? ?? '';
                if (id.startsWith('place') || id.startsWith('region') || id.startsWith('locality')) {
                  city = item['text'] as String? ?? city;
                  break;
                }
              }
            }

            final generatedTitle = '$placeText Parking';
            return GeocodingResult(
              title: generatedTitle,
              fullAddress: fullAddress,
              city: city,
            );
          }
        }
      } catch (_) {
        // Fallback to OpenStreetMap Nominatim below
      }
    }

    // Fallback: OpenStreetMap Nominatim API
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'MeeParkingApp/1.0'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String? ?? 'Selected Location';
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['road'] ?? address['city_district'] ?? address['city'] ?? 'Local';
        final city = address['city'] ?? address['town'] ?? address['state_district'] ?? 'Selected Area';

        return GeocodingResult(
          title: '$suburb Parking',
          fullAddress: displayName,
          city: city.toString(),
        );
      }
    } catch (_) {}

    // Sensible fallback when offline or no network response
    return GeocodingResult(
      title: 'Selected Location Parking',
      fullAddress: 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
      city: 'Current Area',
    );
  }
}
