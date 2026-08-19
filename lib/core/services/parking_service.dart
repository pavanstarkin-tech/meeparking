import '../../shared/models/parking_space.dart';
import 'firebase_rtdb_service.dart';

class ParkingService {
  static Future<List<ParkingSpace>> getSpaces({
    String query = '',
    bool filterEvOnly = false,
    bool filterCoveredOnly = false,
    bool filterCctvOnly = false,
  }) async {
    final spaces = await FirebaseRtdbService.streamParkingSpaces().first;
    return spaces.where((space) {
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        final matchesQuery = space.title.toLowerCase().contains(q) ||
            space.address.toLowerCase().contains(q) ||
            space.city.toLowerCase().contains(q);
        if (!matchesQuery) return false;
      }
      if (filterEvOnly && !space.isEvChargingAvailable) return false;
      if (filterCoveredOnly && !space.amenities.contains('Covered')) return false;
      if (filterCctvOnly && !space.amenities.contains('CCTV')) return false;
      return true;
    }).toList();
  }

  static Future<ParkingSpace?> getSpaceById(String id) async {
    final spaces = await FirebaseRtdbService.streamParkingSpaces().first;
    try {
      return spaces.firstWhere((s) => s.id == id);
    } catch (_) {
      return spaces.isNotEmpty ? spaces.first : null;
    }
  }

  static Future<List<ParkingSpace>> getPartnerListings(String partnerId) async {
    final spaces = await FirebaseRtdbService.streamParkingSpaces().first;
    return spaces.where((s) => s.ownerId == partnerId).toList();
  }

  static Future<bool> addParkingSpace(ParkingSpace space) async {
    await FirebaseRtdbService.addParkingSpace(space);
    return true;
  }
}
