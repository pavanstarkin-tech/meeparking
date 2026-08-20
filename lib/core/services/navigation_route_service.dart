import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/env_config.dart';

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final String modifier;
  final String type;

  RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.modifier,
    required this.type,
  });

  IconData get icon {
    final t = type.toLowerCase();
    final m = modifier.toLowerCase();
    final inst = instruction.toLowerCase();

    if (t.contains('arrive') || inst.contains('arrive') || inst.contains('reached')) return Icons.pin_drop_rounded;
    if (m.contains('uturn') || t.contains('uturn') || inst.contains('u-turn')) return Icons.u_turn_left_rounded;
    if (m.contains('sharp right') || inst.contains('sharp right')) return Icons.turn_sharp_right_rounded;
    if (m.contains('sharp left') || inst.contains('sharp left')) return Icons.turn_sharp_left_rounded;
    if (m.contains('slight right') || inst.contains('slight right') || inst.contains('bear right')) return Icons.turn_slight_right_rounded;
    if (m.contains('slight left') || inst.contains('slight left') || inst.contains('bear left')) return Icons.turn_slight_left_rounded;
    if (m.contains('right') || t.contains('right') || inst.contains('turn right')) return Icons.turn_right_rounded;
    if (m.contains('left') || t.contains('left') || inst.contains('turn left')) return Icons.turn_left_rounded;
    if (t.contains('roundabout') || t.contains('rotary') || inst.contains('roundabout')) return Icons.roundabout_right_rounded;
    if (t.contains('fork') || inst.contains('fork')) return (m.contains('left') || inst.contains('left')) ? Icons.fork_left_rounded : Icons.fork_right_rounded;
    if (t.contains('merge') || inst.contains('merge')) return Icons.merge_rounded;
    if (m.contains('straight') || t.contains('continue') || t.contains('depart') || inst.contains('straight') || inst.contains('continue') || inst.contains('drive') || inst.contains('head') || inst.contains('east') || inst.contains('west') || inst.contains('north') || inst.contains('south')) {
      return Icons.straight_rounded;
    }
    return Icons.straight_rounded;
  }
}

class NavigationRouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final List<RouteStep> steps;
  final String summary;

  NavigationRouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.steps,
    required this.summary,
  });
}

class NavigationRouteService {
  /// Fetch real driving route from Mapbox Directions API (with OSRM fallback)
  static Future<NavigationRouteResult?> fetchDrivingRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final token = EnvConfig.mapboxAccessToken;

    // 1. Try Mapbox Directions API
    if (token.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}'
          '?geometries=geojson&steps=true&overview=full&access_token=$token',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes.first;
            final geometry = route['geometry'];
            final coords = (geometry['coordinates'] as List?) ?? [];
            final List<LatLng> points = coords.map((c) {
              final lng = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              return LatLng(lat, lng);
            }).toList();

            final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
            final durationSecs = (route['duration'] as num?)?.toDouble() ?? 0.0;

            final List<RouteStep> steps = [];
            final legs = route['legs'] as List?;
            if (legs != null && legs.isNotEmpty) {
              final rawSteps = legs.first['steps'] as List?;
              if (rawSteps != null) {
                for (final s in rawSteps) {
                  final maneuver = s['maneuver'] as Map<String, dynamic>?;
                  final instruction = maneuver?['instruction'] as String? ?? '';
                  final modifier = maneuver?['modifier'] as String? ?? '';
                  final type = maneuver?['type'] as String? ?? '';
                  final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
                  if (instruction.isNotEmpty) {
                    steps.add(RouteStep(
                      instruction: instruction,
                      distanceMeters: dist,
                      modifier: modifier,
                      type: type,
                    ));
                  }
                }
              }
            }

            if (steps.isEmpty) {
              steps.add(RouteStep(
                instruction: 'Head towards destination on fastest road',
                distanceMeters: distanceMeters,
                modifier: 'straight',
                type: 'depart',
              ));
            }

            return NavigationRouteResult(
              points: points,
              distanceKm: double.parse((distanceMeters / 1000.0).toStringAsFixed(1)),
              durationMinutes: (durationSecs / 60.0).ceil().clamp(1, 999),
              steps: steps,
              summary: (route['legs'] != null && (route['legs'] as List).isNotEmpty)
                  ? ((route['legs'][0]['summary'] ?? '') as String)
                  : '',
            );
          }
        }
      } catch (e) {
        debugPrint('Mapbox Directions error, trying OSRM fallback: $e');
      }
    }

    // 2. Open Source Routing Machine (OSRM) Fallback (Public & Free)
    try {
      final osrmUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );
      final response = await http.get(osrmUrl).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first;
          final coords = (route['geometry']['coordinates'] as List?) ?? [];
          final List<LatLng> points = coords.map((c) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSecs = (route['duration'] as num?)?.toDouble() ?? 0.0;

          final List<RouteStep> steps = [];
          final legs = route['legs'] as List?;
          if (legs != null && legs.isNotEmpty) {
            final rawSteps = legs.first['steps'] as List?;
            if (rawSteps != null) {
              for (final s in rawSteps) {
                final maneuver = s['maneuver'] as Map<String, dynamic>?;
                final instruction = maneuver?['instruction'] as String? ?? '';
                final modifier = maneuver?['modifier'] as String? ?? '';
                final type = maneuver?['type'] as String? ?? '';
                final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
                if (instruction.isNotEmpty) {
                  steps.add(RouteStep(
                    instruction: instruction,
                    distanceMeters: dist,
                    modifier: modifier,
                    type: type,
                  ));
                }
              }
            }
          }

          if (steps.isEmpty) {
            steps.add(RouteStep(
              instruction: 'Drive towards parking spot',
              distanceMeters: distanceMeters,
              modifier: 'straight',
              type: 'depart',
            ));
          }

          return NavigationRouteResult(
            points: points,
            distanceKm: double.parse((distanceMeters / 1000.0).toStringAsFixed(1)),
            durationMinutes: (durationSecs / 60.0).ceil().clamp(1, 999),
            steps: steps,
            summary: '',
          );
        }
      }
    } catch (e) {
      debugPrint('OSRM routing error: $e');
    }

    return null;
  }
}
