class ChatConversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;
  final String otherUserPhone;
  final String otherUserRole; // 'partner' or 'user'
  final String spaceTitle;
  final String spaceAddress;
  final String vehicleInfo;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final int unreadCount;
  final String? bookingId;

  ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto = '',
    this.otherUserPhone = '',
    this.otherUserRole = 'user',
    this.spaceTitle = '',
    this.spaceAddress = '',
    this.vehicleInfo = '',
    this.lastMessage = '',
    required this.lastMessageTime,
    this.lastSenderId = '',
    this.unreadCount = 0,
    this.bookingId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserPhoto': otherUserPhoto,
      'otherUserPhone': otherUserPhone,
      'otherUserRole': otherUserRole,
      'spaceTitle': spaceTitle,
      'spaceAddress': spaceAddress,
      'vehicleInfo': vehicleInfo,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
      'bookingId': bookingId,
    };
  }

  factory ChatConversation.fromMap(Map<String, dynamic> map, [String? docId]) {
    return ChatConversation(
      id: docId ?? map['id'] ?? '',
      otherUserId: map['otherUserId'] ?? '',
      otherUserName: map['otherUserName'] ?? 'User',
      otherUserPhoto: map['otherUserPhoto'] ?? '',
      otherUserPhone: map['otherUserPhone'] ?? '',
      otherUserRole: map['otherUserRole'] ?? 'user',
      spaceTitle: map['spaceTitle'] ?? '',
      spaceAddress: map['spaceAddress'] ?? '',
      vehicleInfo: map['vehicleInfo'] ?? '',
      lastMessage: map['lastMessage'] ?? 'Tap to view conversation',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'])
              : DateTime.tryParse(map['lastMessageTime'].toString()) ?? DateTime.now())
          : DateTime.now(),
      lastSenderId: map['lastSenderId'] ?? '',
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      bookingId: map['bookingId'],
    );
  }
}
