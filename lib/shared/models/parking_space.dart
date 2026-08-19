class VehicleCategoryRates {
  final double hourly;
  final double daily;
  final double weekly;
  final double monthly;

  VehicleCategoryRates({
    required this.hourly,
    required this.daily,
    required this.weekly,
    required this.monthly,
  });

  Map<String, dynamic> toJson() => {
        'hourly': hourly,
        'daily': daily,
        'weekly': weekly,
        'monthly': monthly,
      };

  factory VehicleCategoryRates.fromJson(Map<String, dynamic> json) {
    return VehicleCategoryRates(
      hourly: (json['hourly'] as num?)?.toDouble() ?? 0.0,
      daily: (json['daily'] as num?)?.toDouble() ?? 0.0,
      weekly: (json['weekly'] as num?)?.toDouble() ?? 0.0,
      monthly: (json['monthly'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ParkingPricing {
  final double hourly;
  final double daily;
  final double weekly;
  final double monthly;

  final VehicleCategoryRates twoWheeler;
  final VehicleCategoryRates threeWheeler;
  final VehicleCategoryRates fourWheeler;

  ParkingPricing({
    required this.hourly,
    required this.daily,
    required this.weekly,
    required this.monthly,
    VehicleCategoryRates? twoWheeler,
    VehicleCategoryRates? threeWheeler,
    VehicleCategoryRates? fourWheeler,
  })  : twoWheeler = twoWheeler ?? VehicleCategoryRates(hourly: hourly / 2, daily: daily / 2, weekly: weekly / 2, monthly: monthly / 2),
        threeWheeler = threeWheeler ?? VehicleCategoryRates(hourly: hourly * 0.75, daily: daily * 0.75, weekly: weekly * 0.75, monthly: monthly * 0.75),
        fourWheeler = fourWheeler ?? VehicleCategoryRates(hourly: hourly, daily: daily, weekly: weekly, monthly: monthly);

  Map<String, dynamic> toJson() => {
        'hourly': hourly,
        'daily': daily,
        'weekly': weekly,
        'monthly': monthly,
        'twoWheeler': twoWheeler.toJson(),
        'threeWheeler': threeWheeler.toJson(),
        'fourWheeler': fourWheeler.toJson(),
      };

  Map<String, dynamic> toMap() => toJson();

  factory ParkingPricing.fromJson(Map<String, dynamic> json) {
    final defaultHourly = (json['hourly'] as num?)?.toDouble() ?? 60.0;
    final defaultDaily = (json['daily'] as num?)?.toDouble() ?? 300.0;
    final defaultWeekly = (json['weekly'] as num?)?.toDouble() ?? 1500.0;
    final defaultMonthly = (json['monthly'] as num?)?.toDouble() ?? 4500.0;

    return ParkingPricing(
      hourly: defaultHourly,
      daily: defaultDaily,
      weekly: defaultWeekly,
      monthly: defaultMonthly,
      twoWheeler: json['twoWheeler'] != null
          ? VehicleCategoryRates.fromJson(Map<String, dynamic>.from(json['twoWheeler']))
          : VehicleCategoryRates(hourly: defaultHourly * 0.5, daily: defaultDaily * 0.5, weekly: defaultWeekly * 0.5, monthly: defaultMonthly * 0.5),
      threeWheeler: json['threeWheeler'] != null
          ? VehicleCategoryRates.fromJson(Map<String, dynamic>.from(json['threeWheeler']))
          : VehicleCategoryRates(hourly: defaultHourly * 0.75, daily: defaultDaily * 0.75, weekly: defaultWeekly * 0.75, monthly: defaultMonthly * 0.75),
      fourWheeler: json['fourWheeler'] != null
          ? VehicleCategoryRates.fromJson(Map<String, dynamic>.from(json['fourWheeler']))
          : VehicleCategoryRates(hourly: defaultHourly, daily: defaultDaily, weekly: defaultWeekly, monthly: defaultMonthly),
    );
  }

  factory ParkingPricing.fromMap(Map<String, dynamic> map) => ParkingPricing.fromJson(map);
}

class LandCapacity {
  final double totalLandSqMeters;
  final int maxCars;
  final int maxBikes;
  final int currentCars;
  final int currentBikes;

  LandCapacity({
    required this.totalLandSqMeters,
    required this.maxCars,
    required this.maxBikes,
    required this.currentCars,
    required this.currentBikes,
  });

  int get remainingCars => maxCars - currentCars > 0 ? maxCars - currentCars : 0;
  int get remainingBikes => maxBikes - currentBikes > 0 ? maxBikes - currentBikes : 0;

  Map<String, dynamic> toJson() => {
        'totalLandSqMeters': totalLandSqMeters,
        'maxCars': maxCars,
        'maxBikes': maxBikes,
        'currentCars': currentCars,
        'currentBikes': currentBikes,
      };

  Map<String, dynamic> toMap() => toJson();

  factory LandCapacity.fromJson(Map<String, dynamic> json) {
    return LandCapacity(
      totalLandSqMeters: (json['totalLandSqMeters'] as num?)?.toDouble() ?? 120.0,
      maxCars: json['maxCars'] ?? 20,
      maxBikes: json['maxBikes'] ?? 30,
      currentCars: json['currentCars'] ?? 2,
      currentBikes: json['currentBikes'] ?? 5,
    );
  }

  factory LandCapacity.fromMap(Map<String, dynamic> map) => LandCapacity.fromJson(map);
}

typedef ParkingCapacity = LandCapacity;
typedef PricingDetails = ParkingPricing;

class ParkingSpace {
  final String id;
  final String ownerId;
  final String title;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final List<String> images;
  final String description;
  final List<String> amenities; // ['CCTV', 'Covered', 'Security', 'EV Charger']
  final LandCapacity capacity;
  final ParkingPricing pricing;
  final String status; // 'active' | 'inactive'
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final bool hasEvCharging;
  final List<List<double>>? polygonCoordinates;

  ParkingSpace({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
    required this.images,
    required this.description,
    required this.amenities,
    required this.capacity,
    required this.pricing,
    required this.status,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    this.hasEvCharging = false,
    this.polygonCoordinates,
  });

  static String sanitizeAmenity(String text) {
    if (text.isEmpty) return '';
    final stripped = text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}'
        r'|\u{1F300}-\u{1F5FF}'
        r'|\u{1F680}-\u{1F6FF}'
        r'|\u{1F700}-\u{1F77F}'
        r'|\u{1F780}-\u{1F7FF}'
        r'|\u{1F800}-\u{1F8FF}'
        r'|\u{1F900}-\u{1F9FF}'
        r'|\u{1FA00}-\u{1FA6F}'
        r'|\u{1FA70}-\u{1FAFF}'
        r'|\u{2600}-\u{26FF}'
        r'|\u{2700}-\u{27BF}'
        r'|\u{FE00}-\u{FE0F}'
        r'|\u{1F1E6}-\u{1F1FF}'
        r']+',
        unicode: true,
      ),
      '',
    );
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool get isAvailable => capacity.remainingCars > 0;
  bool get isActive => status == 'active';
  bool get isEvChargingAvailable => hasEvCharging || amenities.contains('EV Charger');

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'title': title,
        'address': address,
        'city': city,
        'lat': lat,
        'lng': lng,
        'images': images,
        'description': description,
        'amenities': amenities.map(sanitizeAmenity).where((e) => e.isNotEmpty).toSet().toList(),
        'capacity': capacity.toJson(),
        'pricing': pricing.toJson(),
        'status': status,
        'rating': rating,
        'reviewCount': reviewCount,
        'distanceKm': distanceKm,
        'hasEvCharging': hasEvCharging,
        'polygonCoordinates': polygonCoordinates,
      };

  Map<String, dynamic> toMap() => toJson();

  factory ParkingSpace.fromJson(Map<String, dynamic> json, [String? docId]) {
    return ParkingSpace(
      id: docId ?? json['id'] ?? '',
      ownerId: json['ownerId'] ?? '',
      title: json['title'] ?? 'CP Tower Parking',
      address: json['address'] ?? 'Connaught Place, Delhi',
      city: json['city'] ?? 'Delhi',
      lat: (json['lat'] as num?)?.toDouble() ?? 28.6315,
      lng: (json['lng'] as num?)?.toDouble() ?? 77.2167,
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      description: json['description'] ?? 'Secure multi-level parking space with 24/7 CCTV surveillance.',
      amenities: (json['amenities'] as List?)
              ?.map((e) => sanitizeAmenity(e.toString()))
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList() ??
          ['CCTV', 'Covered', 'Security', 'EV Charger'],
      capacity: json['capacity'] != null
          ? LandCapacity.fromJson(Map<String, dynamic>.from(json['capacity']))
          : LandCapacity(totalLandSqMeters: 100, maxCars: 20, maxBikes: 30, currentCars: 2, currentBikes: 5),
      pricing: json['pricing'] != null
          ? ParkingPricing.fromJson(Map<String, dynamic>.from(json['pricing']))
          : ParkingPricing(hourly: 60, daily: 300, weekly: 1500, monthly: 4500),
      status: json['status'] ?? 'active',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.6,
      reviewCount: json['reviewCount'] ?? 128,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 2.4,
      hasEvCharging: json['hasEvCharging'] ?? true,
      polygonCoordinates: (json['polygonCoordinates'] as List?)
          ?.map((point) => (point as List).map((c) => (c as num).toDouble()).toList())
          .toList(),
    );
  }

  factory ParkingSpace.fromMap(Map<String, dynamic> map, [String? docId]) => ParkingSpace.fromJson(map, docId);
}
