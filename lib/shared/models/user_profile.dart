class Vehicle {
  final String id;
  final String number;
  final String model;
  final String type; // '4-Wheeler' | '2-Wheeler' | '3-Wheeler' or 'car' | 'bike' | 'auto'

  Vehicle({
    required this.id,
    required this.number,
    required this.model,
    required this.type,
  });

  String get category {
    final t = type.toLowerCase();
    if (t.contains('2') || t.contains('bike') || t.contains('scooter') || t.contains('two')) {
      return '2-Wheeler';
    }
    if (t.contains('3') || t.contains('auto') || t.contains('rickshaw') || t.contains('three')) {
      return '3-Wheeler';
    }
    return '4-Wheeler';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'model': model,
        'type': type,
      };

  Map<String, dynamic> toMap() => toJson();

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? '',
      number: json['number'] ?? json['regNo'] ?? '',
      model: json['model'] ?? '',
      type: json['type'] ?? json['category'] ?? '4-Wheeler',
    );
  }
}


class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  final String role; // 'user' | 'partner'
  final double walletBalance;
  final String fcmToken;
  final List<Vehicle> vehicles;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.role,
    required this.walletBalance,
    required this.fcmToken,
    required this.vehicles,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? role,
    double? walletBalance,
    String? fcmToken,
    List<Vehicle>? vehicles,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      walletBalance: walletBalance ?? this.walletBalance,
      fcmToken: fcmToken ?? this.fcmToken,
      vehicles: vehicles ?? this.vehicles,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'role': role,
        'walletBalance': walletBalance,
        'fcmToken': fcmToken,
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'Guest User',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      role: json['role'] ?? 'user',
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 1250.0,
      fcmToken: json['fcmToken'] ?? '',
      vehicles: (json['vehicles'] as List?)
              ?.map((v) => Vehicle.fromJson(Map<String, dynamic>.from(v)))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
