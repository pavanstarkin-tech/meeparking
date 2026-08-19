import 'package:uuid/uuid.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/chat_conversation.dart';
import 'firebase_rtdb_service.dart';

class ChatService {
  /// Generate deterministic Chat ID derived from 2 user IDs
  static String getChatId(String user1Id, String user2Id) {
    final list = [user1Id, user2Id]..sort();
    return 'chat_${list[0]}_${list[1]}';
  }

  /// Stream real-time chat messages between two users
  static Stream<List<ChatMessage>> streamMessages({
    required String currentUserId,
    required String partnerId,
  }) {
    final chatId = getChatId(currentUserId, partnerId);
    return FirebaseRtdbService.streamChatMessages(chatId).map((messages) {
      return messages.map((m) {
        return ChatMessage(
          id: m.id,
          senderId: m.senderId,
          senderName: m.senderName,
          text: m.text,
          timestamp: m.timestamp,
          isMe: m.senderId == currentUserId,
        );
      }).toList();
    });
  }

  /// Send real-time chat message with conversation metadata update
  static Future<void> sendMessage({
    required String currentUserId,
    required String currentUserName,
    required String partnerId,
    required String text,
    String? partnerName,
    String? partnerPhoto,
    String? spaceTitle,
    String? spaceAddress,
    String? vehicleInfo,
    String? partnerRole,
  }) async {
    if (text.trim().isEmpty) return;
    final chatId = getChatId(currentUserId, partnerId);
    final msg = ChatMessage(
      id: 'msg_${const Uuid().v4().substring(0, 8)}',
      senderId: currentUserId,
      senderName: currentUserName.isNotEmpty ? currentUserName : 'User',
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    final meta = <String, dynamic>{
      'participants': [currentUserId, partnerId],
      if (partnerName != null && partnerName.isNotEmpty) 'otherUserName': partnerName,
      if (partnerPhoto != null && partnerPhoto.isNotEmpty) 'otherUserPhoto': partnerPhoto,
      if (spaceTitle != null && spaceTitle.isNotEmpty) 'spaceTitle': spaceTitle,
      if (spaceAddress != null && spaceAddress.isNotEmpty) 'spaceAddress': spaceAddress,
      if (vehicleInfo != null && vehicleInfo.isNotEmpty) 'vehicleInfo': vehicleInfo,
      if (partnerRole != null && partnerRole.isNotEmpty) 'otherUserRole': partnerRole,
    };

    await FirebaseRtdbService.sendMessage(chatId, msg, conversationMeta: meta);
  }

  /// Stream user conversations list
  static Stream<List<ChatConversation>> streamConversations(String userId, {bool isPartner = false}) {
    return FirebaseRtdbService.streamUserConversations(userId, isPartner: isPartner);
  }
}
