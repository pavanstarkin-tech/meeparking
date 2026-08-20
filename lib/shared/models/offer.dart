class Offer {
  final String id;
  final String code;
  final String title;
  final String description;
  final String discountType; // 'percentage' | 'flat'
  final double discountValue;
  final double? maxDiscount;
  final double minBookingAmount;
  final String category; // 'all' | 'first_booking' | 'weekend' | 'ev'
  final bool isActive;
  final String? validTill;
  final String color;
  final DateTime createdAt;

  const Offer({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    this.discountType = 'percentage',
    required this.discountValue,
    this.maxDiscount,
    this.minBookingAmount = 0.0,
    this.category = 'all',
    this.isActive = true,
    this.validTill,
    this.color = '#7C3AED',
    required this.createdAt,
  });

  factory Offer.fromMap(String id, Map<dynamic, dynamic> map) {
    return Offer(
      id: id,
      code: (map['code'] ?? id).toString().toUpperCase(),
      title: map['title']?.toString() ?? 'Special Discount',
      description: map['description']?.toString() ?? '',
      discountType: map['discountType']?.toString() ?? 'percentage',
      discountValue: (map['discountValue'] is num) ? (map['discountValue'] as num).toDouble() : 0.0,
      maxDiscount: (map['maxDiscount'] is num) ? (map['maxDiscount'] as num).toDouble() : null,
      minBookingAmount: (map['minBookingAmount'] is num) ? (map['minBookingAmount'] as num).toDouble() : 0.0,
      category: map['category']?.toString() ?? 'all',
      isActive: map['isActive'] != false,
      validTill: map['validTill']?.toString(),
      color: map['color']?.toString() ?? '#7C3AED',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.toUpperCase(),
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      if (maxDiscount != null) 'maxDiscount': maxDiscount,
      'minBookingAmount': minBookingAmount,
      'category': category,
      'isActive': isActive,
      if (validTill != null) 'validTill': validTill,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Calculates the discount amount for a given booking total amount.
  double calculateDiscount(double originalAmount) {
    if (!isActive) return 0.0;
    if (originalAmount < minBookingAmount) return 0.0;

    double calculated = 0.0;
    if (discountType == 'percentage') {
      calculated = (originalAmount * discountValue) / 100.0;
      if (maxDiscount != null && maxDiscount! > 0 && calculated > maxDiscount!) {
        calculated = maxDiscount!;
      }
    } else {
      // Flat discount
      calculated = discountValue;
    }

    // Never exceed original amount
    if (calculated > originalAmount) {
      calculated = originalAmount;
    }

    return calculated;
  }
}
