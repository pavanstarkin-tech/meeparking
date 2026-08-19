class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  Map<String, dynamic> toMap() => toJson();

  factory ChatMessage.fromJson(Map<String, dynamic> json, [String? docId, String? currentUserId]) {
    final sId = (json['senderId'] ?? '').toString();
    final cId = currentUserId ?? 'user_auth_01';
    return ChatMessage(
      id: docId ?? json['id'] ?? '',
      senderId: sId,
      senderName: json['senderName'] ?? 'User',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()) : DateTime.now(),
      isMe: sId.isNotEmpty && (sId == cId || (cId == 'user_auth_01' && sId.startsWith('user_')) || (cId == 'partner_01' && sId.startsWith('partner_'))),
    );
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, [String? docId, String? currentUserId]) => ChatMessage.fromJson(map, docId, currentUserId);
}
