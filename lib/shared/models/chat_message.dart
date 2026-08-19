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

  factory ChatMessage.fromJson(Map<String, dynamic> json, [String? docId]) {
    final sId = json['senderId'] ?? '';
    return ChatMessage(
      id: docId ?? json['id'] ?? '',
      senderId: sId,
      senderName: json['senderName'] ?? 'User',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      isMe: sId == 'user_01',
    );
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, [String? docId]) => ChatMessage.fromJson(map, docId);
}
