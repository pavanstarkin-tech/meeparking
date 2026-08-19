class PartnerPayoutRecord {
  final String id;
  final String partnerId;
  final double amount;
  final String status; // 'paid' | 'completed' | 'processing' | 'pending' | 'rejected'
  final String transactionRef;
  final String paymentMode; // 'Bank Transfer' | 'UPI' | 'IMPS' | 'NEFT'
  final String bankName;
  final String accountNumber;
  final String upiId;
  final String adminName;
  final String adminNotes;
  final String createdAt;
  final String? processedAt;

  PartnerPayoutRecord({
    required this.id,
    required this.partnerId,
    required this.amount,
    this.status = 'paid',
    this.transactionRef = '',
    this.paymentMode = 'Bank Transfer',
    this.bankName = '',
    this.accountNumber = '',
    this.upiId = '',
    this.adminName = 'Admin Finance Team',
    this.adminNotes = '',
    required this.createdAt,
    this.processedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'partnerId': partnerId,
        'amount': amount,
        'status': status,
        'transactionRef': transactionRef,
        'paymentMode': paymentMode,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'upiId': upiId,
        'adminName': adminName,
        'adminNotes': adminNotes,
        'createdAt': createdAt,
        'processedAt': processedAt,
      };

  Map<String, dynamic> toMap() => toJson();

  factory PartnerPayoutRecord.fromJson(Map<String, dynamic> json, [String? docId]) {
    return PartnerPayoutRecord(
      id: docId ?? json['id']?.toString() ?? '',
      partnerId: json['partnerId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString().toLowerCase() ?? 'paid',
      transactionRef: json['transactionRef']?.toString() ??
          json['txnRef']?.toString() ??
          json['utr']?.toString() ??
          json['reference']?.toString() ??
          '',
      paymentMode: json['paymentMode']?.toString() ?? json['mode']?.toString() ?? 'Bank Transfer',
      bankName: json['bankName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      upiId: json['upiId']?.toString() ?? '',
      adminName: json['adminName']?.toString() ??
          json['processedBy']?.toString() ??
          json['admin']?.toString() ??
          'Admin Panel',
      adminNotes: json['adminNotes']?.toString() ??
          json['notes']?.toString() ??
          json['remarks']?.toString() ??
          '',
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      processedAt: json['processedAt']?.toString(),
    );
  }

  factory PartnerPayoutRecord.fromMap(Map<String, dynamic> map, [String? docId]) =>
      PartnerPayoutRecord.fromJson(map, docId);
}
