import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../models/parking_space.dart';
import '../models/booking.dart';
import '../models/user_profile.dart';
import '../models/wallet_transaction.dart';

// User Role Provider: 'user' (Seeker) vs 'partner' (Owner)
final currentRoleProvider = StateProvider<String>((ref) => 'user');

// Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filter Providers
final evFilterProvider = StateProvider<bool>((ref) => false);
final coveredFilterProvider = StateProvider<bool>((ref) => false);
final cctvFilterProvider = StateProvider<bool>((ref) => false);

// Parking Spaces Live Realtime Stream Provider
final parkingSpacesStreamProvider = StreamProvider<List<ParkingSpace>>((ref) {
  return FirebaseRtdbService.streamParkingSpaces();
});

// Parking Spaces Filtered Provider
final parkingSpacesProvider = FutureProvider<List<ParkingSpace>>((ref) async {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final ev = ref.watch(evFilterProvider);
  final covered = ref.watch(coveredFilterProvider);
  final cctv = ref.watch(cctvFilterProvider);

  // Read current parking spaces from Firebase Realtime Database
  final snap = await FirebaseRtdbService.db.ref('parkingSpaces').get();
  final data = snap.value;
  final spaces = <ParkingSpace>[];
  if (data is Map) {
    data.forEach((key, value) {
      if (value is Map) {
        try {
          spaces.add(ParkingSpace.fromMap(Map<String, dynamic>.from(value), key.toString()));
        } catch (_) {}
      }
    });
  }

  // Subscribe to realtime database changes so any new listing refreshes the UI automatically
  final sub = FirebaseRtdbService.db.ref('parkingSpaces').onValue.listen((event) {
    if (ref.state is! AsyncLoading) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(() => sub.cancel());

  return spaces.where((s) {
    // Only display parking spaces with defined area boundaries
    if (s.polygonCoordinates == null || s.polygonCoordinates!.length < 3) return false;

    if (query.isNotEmpty) {
      final matches = s.title.toLowerCase().contains(query) ||
          s.address.toLowerCase().contains(query) ||
          s.city.toLowerCase().contains(query);
      if (!matches) return false;
    }
    if (ev && !s.isEvChargingAvailable && !s.hasEvCharging) return false;
    if (covered && !s.amenities.contains('Covered Parking') && !s.amenities.contains('Covered')) return false;
    if (cctv && !s.amenities.contains('CCTV') && !s.amenities.contains('CCTV Surveillance')) return false;
    return true;
  }).toList();
});

// Selected Parking Space Provider
final selectedParkingSpaceProvider = StateProvider<ParkingSpace?>((ref) => null);

// Bookings Live Realtime Stream Provider for current logged in user (or partner in partner mode)
final userBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(userProfileProvider);
  final role = ref.watch(currentRoleProvider);
  if (role == 'partner') {
    return FirebaseRtdbService.streamPartnerBookings(user.uid);
  }
  return FirebaseRtdbService.streamUserBookings(user.uid);
});

// Wallet Balance Live Realtime Stream Provider for current logged in user
final walletBalanceStreamProvider = StreamProvider<double>((ref) {
  final user = ref.watch(userProfileProvider);
  return FirebaseRtdbService.streamWalletBalance(user.uid);
});

// Wallet Transactions Live Realtime Stream Provider for current logged in user
final walletTransactionsProvider = StreamProvider<List<WalletTransaction>>((ref) {
  final user = ref.watch(userProfileProvider);
  return FirebaseRtdbService.streamWalletTransactions(user.uid);
});

// User Profile Provider initialized from authenticated Firebase User
final userProfileProvider = StateProvider<UserProfile>((ref) {
  final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
  if (fbUser != null) {
    return UserProfile(
      uid: fbUser.uid,
      name: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Partner',
      email: fbUser.email ?? '',
      phone: fbUser.phoneNumber ?? '',
      photoUrl: fbUser.photoURL ?? '',
      role: 'user',
      walletBalance: 0.0,
      fcmToken: '',
      vehicles: [],
      createdAt: DateTime.now(),
    );
  }
  return UserProfile(
    uid: 'user_auth_01',
    name: 'Partner User',
    email: 'partner@meeparking.com',
    phone: '',
    photoUrl: '',
    role: 'user',
    walletBalance: 0.0,
    fcmToken: '',
    vehicles: [],
    createdAt: DateTime.now(),
  );
});

// User Added Vehicles Live Realtime Stream Provider
final userVehiclesStreamProvider = StreamProvider<List<Vehicle>>((ref) {
  final user = ref.watch(userProfileProvider);
  return FirebaseRtdbService.streamUserVehicles(user.uid);
});

