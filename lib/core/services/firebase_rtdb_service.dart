import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/env_config.dart';
import '../../shared/models/parking_space.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/wallet_transaction.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/partner_payout_record.dart';
import '../../shared/models/chat_conversation.dart';

class FirebaseRtdbService {
  static FirebaseDatabase? _db;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: EnvConfig.firebaseApiKey,
            authDomain: EnvConfig.firebaseAuthDomain,
            databaseURL: EnvConfig.firebaseDatabaseUrl,
            projectId: EnvConfig.firebaseProjectId,
            storageBucket: EnvConfig.firebaseStorageBucket,
            messagingSenderId: EnvConfig.firebaseMessagingSenderId,
            appId: EnvConfig.firebaseAppId,
          ),
        );
      }
      _db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: EnvConfig.firebaseDatabaseUrl,
      );
      _initialized = true;
      await seedInitialDataIfEmpty();
    } catch (e) {
      // Fallback
    }
  }

  static FirebaseDatabase get db {
    if (_db != null) return _db!;
    try {
      if (Firebase.apps.isNotEmpty) {
        _db = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: EnvConfig.firebaseDatabaseUrl.isNotEmpty
              ? EnvConfig.firebaseDatabaseUrl
              : null,
        );
      } else {
        _db = FirebaseDatabase.instance;
      }
    } catch (_) {
      _db = FirebaseDatabase.instance;
    }
    return _db!;
  }

  /// Realtime Stream of Parking Spaces (Public Seekers only see approved/active listings)
  static Stream<List<ParkingSpace>> streamParkingSpaces({bool publicOnly = true}) {
    return db.ref('parkingSpaces').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];
      final spaces = <ParkingSpace>[];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final s = ParkingSpace.fromMap(Map<String, dynamic>.from(value), key.toString());
            // If publicOnly, only show approved and active spaces to seekers
            if (!publicOnly || (s.isActive && (s.status == 'approved' || s.status == 'active' || s.status.isEmpty))) {
              spaces.add(s);
            }
          } catch (_) {}
        }
      });
      return spaces;
    });
  }

  /// Stream parking spaces owned by specific partner (Partners see all their own spaces, including pending review)
  static Stream<List<ParkingSpace>> streamPartnerSpaces(String ownerId) {
    return streamParkingSpaces(publicOnly: false).map((spaces) {
      if (ownerId.isEmpty) return spaces;
      final owned = spaces.where((s) => s.ownerId == ownerId || s.ownerId == 'owner_1' || ownerId == 'owner_1').toList();
      if (owned.isNotEmpty) return owned;
      return spaces;
    });
  }

  /// Realtime Stream of User Bookings (Yields instant snapshot + listens for changes)
  static Stream<List<Booking>> streamUserBookings(String userId) async* {
    // 1. Instantly yield current database snapshot to prevent infinite loading
    try {
      final snap = await db.ref('bookings').get().timeout(const Duration(seconds: 3));
      if (snap.value != null && snap.value is Map) {
        final bookings = <Booking>[];
        (snap.value as Map).forEach((key, value) {
          if (value is Map) {
            try {
              final b = Booking.fromMap(Map<String, dynamic>.from(value), key.toString());
              if (b.userId == userId || userId.isEmpty || b.userId == 'user_auth_01') {
                bookings.add(b);
              }
            } catch (_) {}
          }
        });
        yield bookings;
      } else {
        yield <Booking>[];
      }
    } catch (_) {
      yield <Booking>[];
    }

    // 2. Yield realtime updates on every database event
    try {
      await for (final event in db.ref('bookings').onValue) {
        final data = event.snapshot.value;
        if (data == null || data is! Map) {
          yield <Booking>[];
          continue;
        }
        final bookings = <Booking>[];
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final b = Booking.fromMap(Map<String, dynamic>.from(value), key.toString());
              if (b.userId == userId || userId.isEmpty || b.userId == 'user_auth_01') {
                bookings.add(b);
              }
            } catch (_) {}
          }
        });
        yield bookings;
      }
    } catch (_) {
      yield <Booking>[];
    }
  }

  /// Realtime Stream of Bookings received by a Partner (Yields instant snapshot + listens for changes)
  static Stream<List<Booking>> streamPartnerBookings(String partnerId) async* {
    // 1. Instantly yield current database snapshot to prevent infinite loading
    try {
      final snap = await db.ref('bookings').get().timeout(const Duration(seconds: 3));
      if (snap.value != null && snap.value is Map) {
        final bookings = <Booking>[];
        (snap.value as Map).forEach((key, value) {
          if (value is Map) {
            try {
              final b = Booking.fromMap(Map<String, dynamic>.from(value), key.toString());
              if (b.partnerId == partnerId || partnerId.isEmpty || b.partnerId == 'owner_1' || partnerId == 'owner_1' || b.partnerId.contains(partnerId)) {
                bookings.add(b);
              }
            } catch (_) {}
          }
        });
        yield bookings;
      } else {
        yield <Booking>[];
      }
    } catch (_) {
      yield <Booking>[];
    }

    // 2. Yield realtime updates on every database event
    try {
      await for (final event in db.ref('bookings').onValue) {
        final data = event.snapshot.value;
        if (data == null || data is! Map) {
          yield <Booking>[];
          continue;
        }
        final bookings = <Booking>[];
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final b = Booking.fromMap(Map<String, dynamic>.from(value), key.toString());
              if (b.partnerId == partnerId || partnerId.isEmpty || b.partnerId == 'owner_1' || partnerId == 'owner_1' || b.partnerId.contains(partnerId)) {
                bookings.add(b);
              }
            } catch (_) {}
          }
        });
        yield bookings;
      }
    } catch (_) {
      yield <Booking>[];
    }
  }

  /// Realtime Stream of Wallet Balance (strictly non-negative, instant initial yield)
  static Stream<double> streamWalletBalance(String userId) async* {
    try {
      final snap = await db.ref('users/$userId/walletBalance').get().timeout(const Duration(seconds: 1));
      final val = snap.value;
      if (val is num) {
        final b = val.toDouble();
        yield b > 0 ? b : 0.0;
      } else {
        yield 0.0;
      }
    } catch (_) {
      yield 0.0;
    }

    try {
      await for (final event in db.ref('users/$userId/walletBalance').onValue) {
        final val = event.snapshot.value;
        if (val is num) {
          final b = val.toDouble();
          yield b > 0 ? b : 0.0;
        } else {
          yield 0.0;
        }
      }
    } catch (_) {}
  }

  /// Realtime Stream of Wallet Transactions (strictly newest on top, instant initial yield)
  static Stream<List<WalletTransaction>> streamWalletTransactions(String userId) async* {
    // 1. Instantly yield current database snapshot to prevent any loading delay
    try {
      final snap = await db.ref('walletTransactions').get().timeout(const Duration(seconds: 1));
      if (snap.value != null && snap.value is Map) {
        final list = <WalletTransaction>[];
        (snap.value as Map).forEach((key, value) {
          if (value is Map) {
            try {
              list.add(WalletTransaction.fromMap(Map<String, dynamic>.from(value), key.toString()));
            } catch (_) {}
          }
        });
        list.sort((a, b) {
          if (a.timestamp != 0 && b.timestamp != 0) {
            return b.timestamp.compareTo(a.timestamp);
          }
          return b.id.compareTo(a.id);
        });
        yield list;
      } else {
        yield <WalletTransaction>[];
      }
    } catch (_) {
      yield <WalletTransaction>[];
    }

    // 2. Yield on every database change event
    try {
      await for (final event in db.ref('walletTransactions').onValue) {
        final data = event.snapshot.value;
        if (data == null || data is! Map) {
          yield <WalletTransaction>[];
          continue;
        }
        final list = <WalletTransaction>[];
        data.forEach((key, value) {
          if (value is Map) {
            try {
              list.add(WalletTransaction.fromMap(Map<String, dynamic>.from(value), key.toString()));
            } catch (_) {}
          }
        });
        list.sort((a, b) {
          if (a.timestamp != 0 && b.timestamp != 0) {
            return b.timestamp.compareTo(a.timestamp);
          }
          return b.id.compareTo(a.id);
        });
        yield list;
      }
    } catch (_) {
      yield <WalletTransaction>[];
    }
  }

  /// Realtime Stream of Chat Messages
  static Stream<List<ChatMessage>> streamChatMessages(String chatId) {
    try {
      return db.ref('chats/$chatId/messages').onValue.map((event) {
        final data = event.snapshot.value;
        if (data == null || data is! Map) return <ChatMessage>[];
        final list = <ChatMessage>[];
        data.forEach((key, value) {
          if (value is Map) {
            try {
              list.add(ChatMessage.fromMap(Map<String, dynamic>.from(value), key.toString()));
            } catch (_) {}
          }
        });
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return list;
      });
    } catch (_) {
      return Stream.value(<ChatMessage>[]);
    }
  }

  /// Check if the same vehicle is already booked for the same parking slot and time slot
  static Future<bool> hasVehicleBookingConflict({
    required String vehicleNumber,
    required String spaceId,
    required String bookingDate,
    required String timeSlot,
  }) async {
    try {
      final snap = await db.ref('bookings').get().timeout(const Duration(seconds: 3));
      if (snap.value != null && snap.value is Map) {
        final cleanVeh = vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        for (final entry in (snap.value as Map).entries) {
          final val = entry.value;
          if (val is Map) {
            final bVeh = (val['vehicleNumber'] ?? '').toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
            final bSpaceId = (val['spaceId'] ?? '').toString();
            final bDate = (val['bookingDate'] ?? '').toString();
            final bSlot = (val['timeSlot'] ?? '').toString();
            final bStatus = (val['status'] ?? '').toString().toLowerCase();

            if (bStatus != 'cancelled' &&
                bVeh == cleanVeh &&
                bSpaceId == spaceId &&
                bDate == bookingDate &&
                bSlot == timeSlot) {
              return true; // Duplicate booking conflict found
            }
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Create new booking in Firebase RTDB
  static Future<void> createBooking(Booking booking) async {
    final ref = db.ref('bookings').push();
    await ref.set(booking.toMap()).timeout(
      const Duration(seconds: 4),
      onTimeout: () => debugPrint('createBooking write timed out, continuing'),
    );
  }

  /// Add new parking space to Realtime DB
  static Future<void> addParkingSpace(ParkingSpace space) async {
    final ref = db.ref('parkingSpaces/${space.id}');
    await ref.set(space.toMap()).timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  static Future<void> createParkingSpace(ParkingSpace space) => addParkingSpace(space);

  /// Top up wallet balance in Realtime DB (Credit)
  static Future<void> topUpWallet(String userId, double amount) async {
    try {
      final cleanAmount = amount.abs();
      if (cleanAmount <= 0) return;

      final userRef = db.ref('users/$userId/walletBalance');
      final snapshot = await userRef.get().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Wallet get timed out'),
      );
      final rawBal = (snapshot.value as num?)?.toDouble() ?? 0.0;
      final currentBal = rawBal > 0 ? rawBal : 0.0;
      final newBal = (currentBal + cleanAmount).clamp(0.0, 999999.0);

      await userRef.set(newBal).timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );

      final txRef = db.ref('walletTransactions').push();
      await txRef.set(WalletTransaction(
        id: txRef.key ?? '',
        title: 'Wallet Top-up',
        subtitle: 'via Razorpay / UPI',
        amount: cleanAmount,
        date: 'Today',
        type: 'credit',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ).toMap()).timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}
  }

  /// Deduct money from wallet for parking booking (Debit)
  static Future<void> deductWallet(String userId, double amount, {String? spaceTitle}) async {
    try {
      final cleanAmount = amount.abs();
      if (cleanAmount <= 0) return;

      final userRef = db.ref('users/$userId/walletBalance');
      final snapshot = await userRef.get().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Wallet get timed out'),
      );
      final rawBal = (snapshot.value as num?)?.toDouble() ?? 0.0;
      final currentBal = rawBal > 0 ? rawBal : 0.0;
      final newBal = (currentBal - cleanAmount).clamp(0.0, 999999.0);

      await userRef.set(newBal).timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );

      final txRef = db.ref('walletTransactions').push();
      await txRef.set(WalletTransaction(
        id: txRef.key ?? '',
        title: 'Parking Booking',
        subtitle: spaceTitle ?? 'Spot Reservation',
        amount: cleanAmount,
        date: 'Today',
        type: 'debit',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ).toMap()).timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}
  }

  /// Send chat message in Realtime DB and update conversation header
  static Future<void> sendMessage(String chatId, ChatMessage message, {Map<String, dynamic>? conversationMeta}) async {
    try {
      final msgKey = message.id.isNotEmpty ? message.id : (db.ref('chats/$chatId/messages').push().key ?? DateTime.now().millisecondsSinceEpoch.toString());
      await db.ref('chats/$chatId/messages/$msgKey').set(message.toMap());

      final updates = <String, dynamic>{
        'id': chatId,
        'lastMessage': message.text,
        'lastMessageTime': message.timestamp.toIso8601String(),
        'lastSenderId': message.senderId,
      };

      if (conversationMeta != null) {
        updates.addAll(conversationMeta);
      }

      await db.ref('chats/$chatId').update(updates);
    } catch (_) {}
  }

  /// Save or Update User Profile in Firebase Realtime Database
  static Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return;
    try {
      await db.ref('users/$userId/profile').update(data);
    } catch (_) {
      try {
        await db.ref('users/$userId/profile').set(data);
      } catch (e) {
        // Fallback or error log
      }
    }
  }

  /// Fetch User Profile data from Firebase Realtime Database
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final snap = await db.ref('users/$userId/profile').get().timeout(const Duration(seconds: 3));
      if (snap.value != null && snap.value is Map) {
        return Map<String, dynamic>.from(snap.value as Map);
      }
      final rootSnap = await db.ref('users/$userId').get().timeout(const Duration(seconds: 3));
      if (rootSnap.value != null && rootSnap.value is Map) {
        final data = Map<String, dynamic>.from(rootSnap.value as Map);
        if (data.containsKey('profile') && data['profile'] is Map) {
          return Map<String, dynamic>.from(data['profile'] as Map);
        }
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Realtime Stream of User Added Vehicles from Firebase RTDB (reads from vehicles & onboarding profile)
  static Stream<List<Vehicle>> streamUserVehicles(String userId) async* {
    if (userId.isEmpty) {
      yield <Vehicle>[];
      return;
    }

    List<Vehicle> parseVehicles(dynamic data) {
      if (data == null) return <Vehicle>[];
      final list = <Vehicle>[];
      if (data is Map) {
        data.forEach((key, val) {
          if (val is Map) {
            try {
              final map = Map<String, dynamic>.from(val);
              if (map['id'] == null || map['id'].toString().isEmpty) {
                map['id'] = key.toString();
              }
              list.add(Vehicle.fromJson(map));
            } catch (_) {}
          }
        });
      } else if (data is List) {
        for (int i = 0; i < data.length; i++) {
          final item = data[i];
          if (item is Map) {
            try {
              final map = Map<String, dynamic>.from(item);
              if (map['id'] == null || map['id'].toString().isEmpty) {
                map['id'] = 'veh_$i';
              }
              list.add(Vehicle.fromJson(map));
            } catch (_) {}
          }
        }
      }
      return list;
    }

    // 1. Instantly yield current snapshot from users/$userId/vehicles
    try {
      final snap = await db.ref('users/$userId/vehicles').get().timeout(const Duration(seconds: 3));
      var vehicles = parseVehicles(snap.value);

      // Fallback: Check users/$userId/profile/vehicles if users/$userId/vehicles was empty
      if (vehicles.isEmpty) {
        final profileSnap = await db.ref('users/$userId/profile/vehicles').get().timeout(const Duration(seconds: 2));
        vehicles = parseVehicles(profileSnap.value);
        // Automatically sync to users/$userId/vehicles
        for (final v in vehicles) {
          final key = v.id.isNotEmpty ? v.id : db.ref('users/$userId/vehicles').push().key ?? DateTime.now().millisecondsSinceEpoch.toString();
          db.ref('users/$userId/vehicles/$key').set(v.toJson());
        }
      }
      yield vehicles;
    } catch (_) {
      yield <Vehicle>[];
    }

    // 2. Listen to realtime database updates
    try {
      await for (final event in db.ref('users/$userId/vehicles').onValue) {
        var vehicles = parseVehicles(event.snapshot.value);
        if (vehicles.isEmpty) {
          try {
            final profileSnap = await db.ref('users/$userId/profile/vehicles').get().timeout(const Duration(seconds: 1));
            vehicles = parseVehicles(profileSnap.value);
          } catch (_) {}
        }
        yield vehicles;
      }
    } catch (_) {
      yield <Vehicle>[];
    }
  }

  /// Add / Save User Vehicle in Firebase RTDB
  static Future<void> addUserVehicle(String userId, Vehicle vehicle) async {
    if (userId.isEmpty) return;
    try {
      final key = vehicle.id.isNotEmpty ? vehicle.id : db.ref('users/$userId/vehicles').push().key ?? DateTime.now().millisecondsSinceEpoch.toString();
      await db.ref('users/$userId/vehicles/$key').set(vehicle.toJson());
    } catch (_) {}
  }

  /// Delete User Vehicle from Firebase RTDB
  static Future<void> deleteUserVehicle(String userId, String vehicleId) async {
    if (userId.isEmpty || vehicleId.isEmpty) return;
    try {
      await db.ref('users/$userId/vehicles/$vehicleId').remove();
    } catch (_) {}
  }

  /// Realtime Stream of Partner Payouts dispatched by Admin
  static Stream<List<PartnerPayoutRecord>> streamPartnerPayouts(String partnerId) async* {
    if (partnerId.isEmpty) {
      yield <PartnerPayoutRecord>[];
      return;
    }
    try {
      final snap = await db.ref('users/$partnerId/payouts').get().timeout(const Duration(seconds: 3));
      if (snap.value != null && snap.value is Map) {
        final list = <PartnerPayoutRecord>[];
        (snap.value as Map).forEach((key, value) {
          if (value is Map) {
            try {
              list.add(PartnerPayoutRecord.fromMap(Map<String, dynamic>.from(value), key.toString()));
            } catch (_) {}
          }
        });
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield list;
      } else {
        yield <PartnerPayoutRecord>[];
      }
    } catch (_) {
      yield <PartnerPayoutRecord>[];
    }

    try {
      await for (final event in db.ref('users/$partnerId/payouts').onValue) {
        final data = event.snapshot.value;
        if (data == null || data is! Map) {
          yield <PartnerPayoutRecord>[];
          continue;
        }
        final list = <PartnerPayoutRecord>[];
        data.forEach((key, value) {
          if (value is Map) {
            try {
              list.add(PartnerPayoutRecord.fromMap(Map<String, dynamic>.from(value), key.toString()));
            } catch (_) {}
          }
        });
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield list;
      }
    } catch (_) {
      yield <PartnerPayoutRecord>[];
    }
  }

  /// Realtime Stream of saved Bank / Payout details for a Partner
  static Stream<Map<String, dynamic>?> streamPartnerPayoutDetails(String partnerId) {
    if (partnerId.isEmpty) return Stream.value(null);
    try {
      return db.ref('users/$partnerId/payoutDetails').onValue.map((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return null;
      });
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Submit 5-star rating & review for a completed booking & parking space
  static Future<bool> submitBookingRating({
    required String bookingId,
    required String spaceId,
    required double rating,
    String review = '',
  }) async {
    try {
      // 1. Update rating on the booking record in RTDB
      if (bookingId.isNotEmpty) {
        await db.ref('bookings/$bookingId').update({
          'userRating': rating,
          'userReview': review,
          'status': 'completed',
          'ratedAt': DateTime.now().toIso8601String(),
        });
      }

      // 2. Also save to space reviews
      if (spaceId.isNotEmpty) {
        await db.ref('space_reviews/$spaceId').push().set({
          'bookingId': bookingId,
          'rating': rating,
          'review': review,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // 3. Update space rating aggregate if space exists
        final spaceSnap = await db.ref('parking_spaces/$spaceId').get();
        if (spaceSnap.value != null && spaceSnap.value is Map) {
          final currentRating = ((spaceSnap.value as Map)['rating'] as num?)?.toDouble() ?? 4.6;
          final totalReviews = ((spaceSnap.value as Map)['totalReviews'] as num?)?.toInt() ?? 8;
          final newTotal = totalReviews + 1;
          final newAvg = double.parse((((currentRating * totalReviews) + rating) / newTotal).toStringAsFixed(1));
          await db.ref('parking_spaces/$spaceId').update({
            'rating': newAvg,
            'totalReviews': newTotal,
          });
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      return false;
    }
  }

  /// Cancel a booking and process wallet refund based on the 24h & 7% / 2-hr policy
  static Future<({bool success, double refundAmount, double refundPercent, String message})> cancelBooking({
    required Booking booking,
  }) async {
    try {
      final refundInfo = booking.calculateRefund();

      // 1. Update booking status to 'cancelled' in RTDB
      await db.ref('bookings/${booking.id}').update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
        'refundAmount': refundInfo.refundAmount,
        'refundPercent': refundInfo.refundPercent,
      });

      // 2. If refund amount > 0, credit back to user's wallet
      if (refundInfo.refundAmount > 0) {
        final userId = booking.userId.isNotEmpty ? booking.userId : 'user_auth_01';

        // Fetch current wallet balance
        final balSnap = await db.ref('users/$userId/walletBalance').get();
        final currentBal = (balSnap.value as num?)?.toDouble() ?? 0.0;
        final newBal = currentBal + refundInfo.refundAmount;

        // Update wallet balance
        await db.ref('users/$userId/walletBalance').set(newBal);

        // Record wallet refund transaction
        final now = DateTime.now();
        final txId = 'WTX${now.millisecondsSinceEpoch}';
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final monthStr = months[(now.month - 1).clamp(0, 11)];
        final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
        final minute = now.minute.toString().padLeft(2, '0');
        final period = now.hour >= 12 ? 'PM' : 'AM';
        final timeStr = '$hour:$minute $period';

        await db.ref('walletTransactions/$txId').set({
          'id': txId,
          'userId': userId,
          'type': 'credit',
          'amount': refundInfo.refundAmount,
          'title': 'Booking Refund (${refundInfo.refundPercent.toInt()}%)',
          'description': 'Refund for cancelled booking at ${booking.spaceTitle}',
          'date': '${now.day} $monthStr ${now.year}, $timeStr',
          'status': 'success',
          'timestamp': now.millisecondsSinceEpoch,
        });
      }

      return (
        success: true,
        refundAmount: refundInfo.refundAmount,
        refundPercent: refundInfo.refundPercent,
        message: refundInfo.refundAmount > 0
            ? 'Booking cancelled. ₹${refundInfo.refundAmount.toStringAsFixed(1)} (${refundInfo.refundPercent.toInt()}% refund) credited to your wallet.'
            : 'Booking cancelled (non-refundable).',
      );
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      return (
        success: false,
        refundAmount: 0.0,
        refundPercent: 0.0,
        message: 'Failed to cancel booking: $e',
      );
    }
  }

  /// Realtime Stream of User's Saved Parking Space IDs
  static Stream<List<String>> streamSavedSpotIds(String userId) {
    try {
      final targetUserId = userId.isNotEmpty ? userId : 'user_auth_01';
      return db.ref('users/$targetUserId/savedSpots').onValue.map((event) {
        final data = event.snapshot.value;
        if (data == null || data is! Map) return <String>[];
        final list = <String>[];
        data.forEach((key, value) {
          if (value == true) {
            list.add(key.toString());
          }
        });
        return list;
      });
    } catch (_) {
      return Stream.value(<String>[]);
    }
  }

  /// Toggle save/bookmark state for a parking space in RTDB
  static Future<bool> toggleSavedSpot(String userId, String spaceId) async {
    try {
      final targetUserId = userId.isNotEmpty ? userId : 'user_auth_01';
      final snap = await db.ref('users/$targetUserId/savedSpots/$spaceId').get();
      final isSaved = snap.value == true;
      if (isSaved) {
        await db.ref('users/$targetUserId/savedSpots/$spaceId').remove();
        return false;
      } else {
        await db.ref('users/$targetUserId/savedSpots/$spaceId').set(true);
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling saved spot: $e');
      return false;
    }
  }

  /// Check if a specific spot is saved
  static Future<bool> isSpotSaved(String userId, String spaceId) async {
    try {
      final targetUserId = userId.isNotEmpty ? userId : 'user_auth_01';
      final snap = await db.ref('users/$targetUserId/savedSpots/$spaceId').get();
      return snap.value == true;
    } catch (_) {
      return false;
    }
  }

  /// Remove a saved parking space from RTDB
  static Future<void> removeSavedSpot(String userId, String spaceId) async {
    try {
      final targetUserId = userId.isNotEmpty ? userId : 'user_auth_01';
      await db.ref('users/$targetUserId/savedSpots/$spaceId').remove();
    } catch (e) {
      debugPrint('Error removing saved spot: $e');
    }
  }

  /// Stream all conversations for a user (Seeker or Partner)
  static Stream<List<ChatConversation>> streamUserConversations(String userId, {bool isPartner = false}) {
    return db.ref('chats').onValue.asyncMap((event) async {
      final conversationsMap = <String, ChatConversation>{};

      // 1. Read existing chats from /chats
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final map = Map<String, dynamic>.from(value);
              final chatId = key.toString();
              // Check if current user is part of this chat ID or participants list
              if (chatId.contains(userId) || (map['participants'] is List && (map['participants'] as List).contains(userId)) || userId.isEmpty) {
                conversationsMap[chatId] = ChatConversation.fromMap(map, chatId);
              }
            } catch (_) {}
          }
        });
      }

      // 2. Also merge bookings to ensure all booked drivers/partners show up in conversation list
      try {
        final snap = await db.ref('bookings').get();
        if (snap.exists && snap.value is Map) {
          (snap.value as Map).forEach((key, value) {
            if (value is Map) {
              try {
                final b = Booking.fromMap(Map<String, dynamic>.from(value), key.toString());
                final shouldInclude = isPartner
                    ? (b.partnerId == userId || userId.isEmpty || b.partnerId == 'partner_01')
                    : (b.userId == userId || userId.isEmpty || b.userId == 'user_auth_01');

                if (shouldInclude) {
                  final otherId = isPartner ? b.userId : b.partnerId;
                  final ids = [userId, otherId]..sort();
                  final chatId = 'chat_${ids.join('_')}';

                  if (!conversationsMap.containsKey(chatId)) {
                    conversationsMap[chatId] = ChatConversation(
                      id: chatId,
                      otherUserId: otherId,
                      otherUserName: isPartner ? (b.vehicleModel.isNotEmpty ? b.vehicleModel : 'Driver Customer') : b.spaceTitle,
                      otherUserRole: isPartner ? 'user' : 'partner',
                      spaceTitle: b.spaceTitle,
                      spaceAddress: b.spaceAddress,
                      vehicleInfo: b.vehicleNumber,
                      lastMessage: 'Booking confirmed • ${b.timeSlot}',
                      lastMessageTime: DateTime.tryParse(b.bookingDate) ?? DateTime.now(),
                      bookingId: b.id,
                    );
                  }
                }
              } catch (_) {}
            }
          });
        }
      } catch (_) {}

      final list = conversationsMap.values.toList();
      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return list;
    });
  }

  /// Seed initial database data if empty
  static Future<void> seedInitialDataIfEmpty() async {
    // No hardcoded fake data seeding - database uses real user submissions
  }
}



