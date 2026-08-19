import 'package:uuid/uuid.dart';
import '../../shared/models/booking.dart';
import 'firebase_rtdb_service.dart';

class BookingService {
  static Future<List<Booking>> getUserBookings(String userId, {String? status}) async {
    final bookings = await FirebaseRtdbService.streamUserBookings(userId).first;
    if (status != null && status.isNotEmpty) {
      return bookings.where((b) => b.status.toLowerCase() == status.toLowerCase()).toList();
    }
    return bookings;
  }

  static Future<List<Booking>> getPartnerBookings(String partnerId) async {
    return FirebaseRtdbService.streamUserBookings('').first;
  }

  static Future<Booking> createBooking({
    required String spaceId,
    required String spaceTitle,
    required String spaceAddress,
    required String vehicleNumber,
    required String vehicleModel,
    required String bookingDate,
    required String timeSlot,
    required double totalAmount,
  }) async {
    final newId = 'MEE${const Uuid().v4().substring(0, 8).toUpperCase()}';
    final booking = Booking(
      id: newId,
      userId: 'user_01',
      spaceId: spaceId,
      partnerId: 'partner_01',
      spaceTitle: spaceTitle,
      spaceAddress: spaceAddress,
      vehicleNumber: vehicleNumber,
      vehicleModel: vehicleModel,
      bookingDate: bookingDate,
      timeSlot: timeSlot,
      totalAmount: totalAmount,
      status: 'upcoming',
      createdAt: DateTime.now().toIso8601String(),
    );
    await FirebaseRtdbService.createBooking(booking);
    return booking;
  }
}
