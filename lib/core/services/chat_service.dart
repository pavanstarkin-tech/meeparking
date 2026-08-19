import 'package:uuid/uuid.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/chat_conversation.dart';
import 'firebase_rtdb_service.dart';

class ChatService {
  /// Generate deterministic Chat ID derived from 2 user IDs
  static String getChatId(String user1Id, String user2Id) {
    final u1 = user1Id.trim().isNotEmpty ? user1Id.trim() : 'user_auth_01';
    final u2 = user2Id.trim().isNotEmpty ? user2Id.trim() : 'partner_01';
    final list = [u1, u2]..sort();
    return 'chat_${list[0]}_${list[1]}';
  }

  /// Stream real-time chat messages between two users
  static Stream<List<ChatMessage>> streamMessages({
    required String currentUserId,
    required String partnerId,
  }) {
    final effectiveUid = currentUserId.trim().isNotEmpty ? currentUserId.trim() : 'user_auth_01';
    final effectivePartnerId = partnerId.trim().isNotEmpty ? partnerId.trim() : 'partner_01';
    final chatId = getChatId(effectiveUid, effectivePartnerId);

    return FirebaseRtdbService.streamChatMessages(chatId).map((messages) {
      return messages.map((m) {
        final isMe = m.senderId == effectiveUid ||
            (effectiveUid == 'user_auth_01' && m.senderId.startsWith('user_')) ||
            (effectiveUid == 'partner_01' && m.senderId.startsWith('partner_'));
        return ChatMessage(
          id: m.id,
          senderId: m.senderId,
          senderName: m.senderName,
          text: m.text,
          timestamp: m.timestamp,
          isMe: isMe,
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

    final effectiveUid = currentUserId.trim().isNotEmpty ? currentUserId.trim() : 'user_auth_01';
    final effectivePartnerId = partnerId.trim().isNotEmpty ? partnerId.trim() : 'partner_01';
    final chatId = getChatId(effectiveUid, effectivePartnerId);

    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 4)}',
      senderId: effectiveUid,
      senderName: currentUserName.trim().isNotEmpty ? currentUserName.trim() : 'User',
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    final meta = <String, dynamic>{
      'participants': [effectiveUid, effectivePartnerId],
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
    final effectiveUid = userId.trim().isNotEmpty ? userId.trim() : (isPartner ? 'partner_01' : 'user_auth_01');
    return FirebaseRtdbService.streamUserConversations(effectiveUid, isPartner: isPartner);
  }
}
