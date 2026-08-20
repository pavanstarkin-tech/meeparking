class Booking {
  final String id;
  final String userId;
  final String spaceId;
  final String partnerId;
  final String spaceTitle;
  final String spaceAddress;
  final String vehicleNumber;
  final String vehicleModel;
  final String vehicleType;
  final String bookingDate; // e.g. "15 Aug 2026" or "15 Aug 2026 - 17 Aug 2026"
  final String timeSlot; // e.g. "09:00 AM (2 hrs)" or "09:00 AM - 11:00 AM"
  final String durationType; // 'hourly' | 'daily' | 'weekly' | 'monthly'
  final double totalAmount;
  final String paymentId;
  final String status; // 'upcoming' | 'parked' | 'completed' | 'cancelled'
  final String entryOtp; // 4-digit Entry OTP
  final String exitOtp; // 4-digit Exit OTP
  final String? parkedAt;
  final String? completedAt;
  final String createdAt;
  final double? userRating;
  final String? userReview;
  final String? couponCode;
  final double? discountAmount;

  Booking({
    required this.id,
    required this.userId,
    required this.spaceId,
    required this.partnerId,
    required this.spaceTitle,
    required this.spaceAddress,
    required this.vehicleNumber,
    this.vehicleModel = 'Honda City',
    this.vehicleType = 'car',
    required this.bookingDate,
    required this.timeSlot,
    this.durationType = 'hourly',
    required this.totalAmount,
    this.paymentId = 'MEE12345678',
    this.status = 'upcoming',
    String? entryOtp,
    String? exitOtp,
    this.parkedAt,
    this.completedAt,
    required this.createdAt,
    this.userRating,
    this.userReview,
    this.couponCode,
    this.discountAmount,
  })  : entryOtp = entryOtp ?? _generateOtp(id, 'entry'),
        exitOtp = exitOtp ?? _generateOtp(id, 'exit');

  static String _generateOtp(String id, String salt) {
    final seed = '${id}_$salt'.hashCode.abs();
    final otpNum = 1000 + (seed % 9000);
    return otpNum.toString();
  }

  /// Check if the booking time slot has passed
  bool get isExpired {
    if (status.toLowerCase() == 'cancelled') return false;
    if (status.toLowerCase() == 'completed') return true;
    final end = getEndDateTime();
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  /// Computed dynamic status ('upcoming' | 'parked' | 'completed' | 'cancelled')
  String get computedStatus {
    final s = status.toLowerCase();
    if (s == 'cancelled') return 'cancelled';
    if (s == 'completed' || isExpired) return 'completed';
    if (s == 'parked' || s == 'in_progress') return 'parked';
    return 'upcoming';
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? spaceId,
    String? partnerId,
    String? spaceTitle,
    String? spaceAddress,
    String? vehicleNumber,
    String? vehicleModel,
    String? vehicleType,
    String? bookingDate,
    String? timeSlot,
    String? durationType,
    double? totalAmount,
    String? paymentId,
    String? status,
    String? entryOtp,
    String? exitOtp,
    String? parkedAt,
    String? completedAt,
    String? createdAt,
    double? userRating,
    String? userReview,
    String? couponCode,
    double? discountAmount,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      spaceId: spaceId ?? this.spaceId,
      partnerId: partnerId ?? this.partnerId,
      spaceTitle: spaceTitle ?? this.spaceTitle,
      spaceAddress: spaceAddress ?? this.spaceAddress,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleType: vehicleType ?? this.vehicleType,
      bookingDate: bookingDate ?? this.bookingDate,
      timeSlot: timeSlot ?? this.timeSlot,
      durationType: durationType ?? this.durationType,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentId: paymentId ?? this.paymentId,
      status: status ?? this.status,
      entryOtp: entryOtp ?? this.entryOtp,
      exitOtp: exitOtp ?? this.exitOtp,
      parkedAt: parkedAt ?? this.parkedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      userRating: userRating ?? this.userRating,
      userReview: userReview ?? this.userReview,
      couponCode: couponCode ?? this.couponCode,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  /// Resolve the exact DateTime when this parking reservation starts
  DateTime? getStartDateTime() {
    try {
      String startDateStr = bookingDate;
      if (bookingDate.contains('-')) {
        startDateStr = bookingDate.split('-').first.trim();
      }

      final baseDate = _parseDate(startDateStr) ?? DateTime.tryParse(startDateStr);
      if (baseDate == null) return null;

      String startTimeStr = timeSlot;
      if (timeSlot.contains('(')) {
        startTimeStr = timeSlot.split('(').first.trim();
      } else if (timeSlot.contains('-')) {
        startTimeStr = timeSlot.split('-').first.trim();
      }

      final timeOfDay = _parseTimeOfDay(startTimeStr);
      if (timeOfDay != null) {
        return DateTime(baseDate.year, baseDate.month, baseDate.day, timeOfDay.hour, timeOfDay.minute);
      }
      return DateTime(baseDate.year, baseDate.month, baseDate.day, 0, 0, 0);
    } catch (_) {}
    return null;
  }

  /// Calculate refund percentage & amount based on the 24-hr (100%) & 7% deduction / 2-hr policy
  ({double refundPercent, double refundAmount, double deductionAmount, double hoursUntilStart, bool isCancellable})
      calculateRefund() {
    final start = getStartDateTime();
    final now = DateTime.now();

    if (start == null) {
      return (
        refundPercent: 100.0,
        refundAmount: totalAmount,
        deductionAmount: 0.0,
        hoursUntilStart: 24.0,
        isCancellable: true,
      );
    }

    final diffMinutes = start.difference(now).inMinutes;
    final hoursUntilStart = diffMinutes / 60.0;

    // If reservation has already started or passed
    if (hoursUntilStart <= 0) {
      return (
        refundPercent: 0.0,
        refundAmount: 0.0,
        deductionAmount: totalAmount,
        hoursUntilStart: hoursUntilStart,
        isCancellable: false,
      );
    }

    // 24+ hours before start: 100% refund (0% deduction)
    if (hoursUntilStart >= 24.0) {
      return (
        refundPercent: 100.0,
        refundAmount: totalAmount,
        deductionAmount: 0.0,
        hoursUntilStart: hoursUntilStart,
        isCancellable: true,
      );
    }

    // Within 24 hours: 7% is deducted for every 2 hours elapsed in the 24-hour window
    final hoursElapsedIn24hWindow = 24.0 - hoursUntilStart;
    final twoHourPeriods = (hoursElapsedIn24hWindow / 2.0).floor();
    final deductionPercent = (twoHourPeriods * 7.0).clamp(0.0, 100.0);
    final refundPercent = (100.0 - deductionPercent).clamp(0.0, 100.0);
    final refundAmount = double.parse((totalAmount * (refundPercent / 100.0)).toStringAsFixed(2));
    final deductionAmount = double.parse((totalAmount - refundAmount).toStringAsFixed(2));

    return (
      refundPercent: refundPercent,
      refundAmount: refundAmount,
      deductionAmount: deductionAmount,
      hoursUntilStart: hoursUntilStart,
      isCancellable: refundPercent > 0,
    );
  }

  /// Resolve the exact DateTime when this parking reservation ends
  DateTime? getEndDateTime() {
    try {
      // 1. Date Range: e.g. "15 Aug 2026 - 17 Aug 2026"
      if (bookingDate.contains('-')) {
        final parts = bookingDate.split('-');
        final endDateStr = parts.last.trim();
        final dt = _parseDate(endDateStr);
        if (dt != null) {
          return DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
        }
      }

      // 2. Single Date: e.g. "15 Aug 2026"
      final baseDate = _parseDate(bookingDate) ?? DateTime.tryParse(bookingDate);
      if (baseDate == null) return null;

      // Check for duration in hours: "09:00 AM (2 hrs)"
      if (timeSlot.contains('(') && timeSlot.contains('hr')) {
        final startPart = timeSlot.split('(').first.trim();
        final hoursMatch = RegExp(r'(\d+)\s*hr').firstMatch(timeSlot);
        final hoursToAdd = hoursMatch != null ? int.parse(hoursMatch.group(1)!) : 2;
        final timeOfDay = _parseTimeOfDay(startPart);
        if (timeOfDay != null) {
          final start = DateTime(baseDate.year, baseDate.month, baseDate.day, timeOfDay.hour, timeOfDay.minute);
          return start.add(Duration(hours: hoursToAdd));
        }
      }

      // Check for slot range: "09:00 AM - 11:00 AM"
      if (timeSlot.contains('-')) {
        final endPart = timeSlot.split('-').last.trim();
        final timeOfDay = _parseTimeOfDay(endPart);
        if (timeOfDay != null) {
          return DateTime(baseDate.year, baseDate.month, baseDate.day, timeOfDay.hour, timeOfDay.minute);
        }
      }

      // Daily / Monthly Pass
      if (timeSlot.toLowerCase().contains('daily') ||
          timeSlot.toLowerCase().contains('monthly') ||
          timeSlot.toLowerCase().contains('pass')) {
        return DateTime(baseDate.year, baseDate.month, baseDate.day, 23, 59, 59);
      }

      // Fallback
      final timeOfDay = _parseTimeOfDay(timeSlot);
      if (timeOfDay != null) {
        return DateTime(baseDate.year, baseDate.month, baseDate.day, timeOfDay.hour + 2, timeOfDay.minute);
      }
    } catch (_) {}
    return null;
  }

  static DateTime? _parseDate(String dateStr) {
    try {
      final months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final parts = dateStr.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]);
        final monthKey = parts[1].toLowerCase().substring(0, 3);
        final month = months[monthKey];
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return null;
  }

  static ({int hour, int minute})? _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final rawTime = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = rawTime.split(':');
      if (parts.isNotEmpty) {
        var hour = int.parse(parts[0]);
        final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return (hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'spaceId': spaceId,
        'partnerId': partnerId,
        'spaceTitle': spaceTitle,
        'spaceAddress': spaceAddress,
        'vehicleNumber': vehicleNumber,
        'vehicleModel': vehicleModel,
        'vehicleType': vehicleType,
        'bookingDate': bookingDate,
        'timeSlot': timeSlot,
        'durationType': durationType,
        'totalAmount': totalAmount,
        'paymentId': paymentId,
        'status': computedStatus,
        'entryOtp': entryOtp,
        'exitOtp': exitOtp,
        'parkedAt': parkedAt,
        'completedAt': completedAt,
        'createdAt': createdAt,
        'userRating': userRating,
        'userReview': userReview,
        if (couponCode != null) 'couponCode': couponCode,
        if (discountAmount != null) 'discountAmount': discountAmount,
      };

  Map<String, dynamic> toMap() => toJson();

  factory Booking.fromJson(Map<String, dynamic> json, [String? docId]) {
    final bId = docId ?? json['id'] ?? '';
    return Booking(
      id: bId,
      userId: json['userId'] ?? '',
      spaceId: json['spaceId'] ?? '',
      partnerId: json['partnerId'] ?? '',
      spaceTitle: json['spaceTitle'] ?? 'CP Tower Parking',
      spaceAddress: json['spaceAddress'] ?? 'Connaught Place, Delhi',
      vehicleNumber: json['vehicleNumber'] ?? 'DL 01 AB 1234',
      vehicleModel: json['vehicleModel'] ?? 'Honda City',
      vehicleType: json['vehicleType'] ?? 'car',
      bookingDate: json['bookingDate'] ?? '20 May 2026',
      timeSlot: json['timeSlot'] ?? '09:00 AM - 11:00 AM',
      durationType: json['durationType'] ?? 'hourly',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 60.0,
      paymentId: json['paymentId'] ?? 'MEE12345678',
      status: json['status'] ?? 'upcoming',
      entryOtp: json['entryOtp']?.toString(),
      exitOtp: json['exitOtp']?.toString(),
      parkedAt: json['parkedAt']?.toString(),
      completedAt: json['completedAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      userRating: (json['userRating'] as num?)?.toDouble(),
      userReview: json['userReview'] as String?,
      couponCode: json['couponCode']?.toString(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
    );
  }

  factory Booking.fromMap(Map<String, dynamic> map, [String? docId]) => Booking.fromJson(map, docId);
}
