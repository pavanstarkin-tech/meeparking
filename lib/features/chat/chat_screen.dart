import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/providers/app_providers.dart';
import 'call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String partnerId;
  final String partnerName;
  final String partnerPhotoUrl;
  final String spaceTitle;
  final String? phone;
  final String? vehicleInfo;
  final String? partnerRole;

  const ChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerPhotoUrl = '',
    this.spaceTitle = '',
    this.phone,
    this.vehicleInfo,
    this.partnerRole,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  late String _resolvedName;
  late String _resolvedPhoto;
  late String _resolvedPhone;
  late String _resolvedSubtitle;
  late String _resolvedRole;

  @override
  void initState() {
    super.initState();
    _resolvedName = widget.partnerName;
    _resolvedPhoto = widget.partnerPhotoUrl;
    _resolvedPhone = widget.phone ?? '';
    _resolvedSubtitle = widget.vehicleInfo?.isNotEmpty == true
        ? '${widget.spaceTitle} • ${widget.vehicleInfo}'
        : widget.spaceTitle;
    _resolvedRole = widget.partnerRole ?? 'Customer (Seeker)';

    _fetchPartnerProfile();
  }

  Future<void> _fetchPartnerProfile() async {
    if (widget.partnerId.isEmpty) return;

    try {
      final profile = await FirebaseRtdbService.getUserProfile(widget.partnerId);
      if (profile != null && mounted) {
        setState(() {
          final pName = (profile['name'] ?? '').toString().trim();
          if (pName.isNotEmpty && (_resolvedName.isEmpty || _resolvedName.startsWith('Customer (') || _resolvedName.startsWith('Driver ('))) {
            _resolvedName = pName;
          }
          final pPhoto = (profile['photoUrl'] ?? '').toString().trim();
          if (pPhoto.isNotEmpty) {
            _resolvedPhoto = pPhoto;
          }
          final pPhone = (profile['phone'] ?? '').toString().trim();
          if (pPhone.isNotEmpty) {
            _resolvedPhone = pPhone;
          }
        });
      }
    } catch (_) {}
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(userProfileProvider);
    _inputController.clear();

    await ChatService.sendMessage(
      currentUserId: user.uid,
      currentUserName: user.name,
      partnerId: widget.partnerId,
      text: text,
    );
  }

  void _startAudioCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          partnerId: widget.partnerId,
          partnerName: _resolvedName,
          partnerPhotoUrl: _resolvedPhoto,
          partnerRole: _resolvedRole,
          subtitle: _resolvedSubtitle,
          phone: _resolvedPhone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF7C3AED),
              backgroundImage: _resolvedPhoto.isNotEmpty
                  ? NetworkImage(_resolvedPhoto)
                  : null,
              child: _resolvedPhoto.isEmpty
                  ? Text(
                      _resolvedName.isNotEmpty
                          ? _resolvedName.trim().substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resolvedName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _resolvedPhone.isNotEmpty
                        ? '$_resolvedSubtitle • $_resolvedPhone'
                        : _resolvedSubtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Voice Call Button Only (No Video Call Button)
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
            tooltip: 'Audio Call',
            onPressed: _startAudioCall,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.streamMessages(
                currentUserId: user.uid,
                partnerId: widget.partnerId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hi to ${widget.partnerName}!',
                      style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),
          // Text Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
                        fillColor: AppColors.backgroundLight,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
            bottomRight: Radius.circular(msg.isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isMe ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: msg.isMe ? Colors.white70 : AppColors.textSecondaryLight,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
