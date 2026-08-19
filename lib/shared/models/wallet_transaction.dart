class WalletTransaction {
  final String id;
  final String title;
  final String subtitle;
  final String date;
  final double amount;
  final String type; // 'credit' | 'debit'
  final int timestamp;

  WalletTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    required this.type,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'date': date,
        'amount': amount.abs(),
        'type': type,
        'timestamp': timestamp,
      };

  Map<String, dynamic> toMap() => toJson();

  factory WalletTransaction.fromJson(Map<String, dynamic> json, [String? docId]) {
    final rawAmount = (json['amount'] as num?)?.toDouble() ?? 500.0;
    final isNegative = rawAmount < 0;
    final cleanAmount = rawAmount.abs();

    String rawType = (json['type'] as String?)?.toLowerCase() ?? 'credit';
    final rawTitle = (json['title'] ?? '').toString();
    final rawSubtitle = (json['subtitle'] ?? '').toString();

    if (isNegative ||
        rawType.contains('debit') ||
        rawTitle.toLowerCase().contains('booking') ||
        rawSubtitle.toLowerCase().contains('parking')) {
      rawType = 'debit';
    }

    String cleanTitle = rawTitle.isNotEmpty ? rawTitle : (rawType == 'debit' ? 'Parking Booking' : 'Wallet Top-up');
    if (cleanTitle == 'Added Money' && rawType == 'debit') {
      cleanTitle = 'Parking Booking';
    }

    String cleanSubtitle = rawSubtitle.isNotEmpty
        ? rawSubtitle
        : (rawType == 'debit' ? 'Spot Reservation' : 'Wallet Top-up via Razorpay');

    return WalletTransaction(
      id: docId ?? json['id'] ?? '',
      title: cleanTitle,
      subtitle: cleanSubtitle,
      date: json['date'] ?? 'Today',
      amount: cleanAmount,
      type: rawType,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map, [String? docId]) =>
      WalletTransaction.fromJson(map, docId);
}
