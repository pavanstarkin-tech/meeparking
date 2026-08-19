import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/chat_conversation.dart';
import '../../shared/providers/app_providers.dart';
import 'chat_screen.dart';
import 'call_screen.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  final bool isPartnerMode;

  const ChatsListScreen({
    super.key,
    this.isPartnerMode = false,
  });

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);
    final userId = user.uid.isNotEmpty ? user.uid : (widget.isPartnerMode ? 'partner_01' : 'user_auth_01');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryLight, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isPartnerMode ? 'Customer Chats' : 'Messages & Support',
              style: const TextStyle(
                color: AppColors.textPrimaryLight,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              widget.isPartnerMode ? 'Direct Host-Customer Comms' : 'Parking Hosts & Space Inquiries',
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isPartnerMode ? AppColors.primary.withOpacity(0.1) : AppColors.greenSuccess.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isPartnerMode ? AppColors.primary.withOpacity(0.3) : AppColors.greenSuccess.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.isPartnerMode ? AppColors.primary : AppColors.greenSuccess,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.isPartnerMode ? 'Host Hub' : 'Seeker',
                  style: TextStyle(
                    color: widget.isPartnerMode ? AppColors.primary : AppColors.greenSuccess,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.textSecondaryLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight),
                      decoration: const InputDecoration(
                        hintText: 'Search customer name, spot, or vehicle...',
                        hintStyle: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.close_rounded, color: AppColors.textSecondaryLight, size: 18),
                    ),
                ],
              ),
            ),
          ),

          // Conversations Stream List
          Expanded(
            child: StreamBuilder<List<ChatConversation>>(
              stream: ChatService.streamConversations(userId, isPartner: widget.isPartnerMode),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final allChats = snapshot.data ?? [];
                final filtered = allChats.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final query = _searchQuery.toLowerCase();
                  return c.otherUserName.toLowerCase().contains(query) ||
                      c.spaceTitle.toLowerCase().contains(query) ||
                      c.spaceAddress.toLowerCase().contains(query) ||
                      c.vehicleInfo.toLowerCase().contains(query) ||
                      c.lastMessage.toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final chat = filtered[index];
                    return ConversationItemTile(
                      chat: chat,
                      isPartnerMode: widget.isPartnerMode,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.isPartnerMode ? 'No Customer Inquiries Yet' : 'No Conversations Yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isPartnerMode
                ? 'Incoming driver inquiries and customer booking questions will appear here.'
                : 'Messages with parking hosts and space managers will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationItemTile extends StatefulWidget {
  final ChatConversation chat;
  final bool isPartnerMode;

  const ConversationItemTile({
    super.key,
    required this.chat,
    required this.isPartnerMode,
  });

  @override
  State<ConversationItemTile> createState() => _ConversationItemTileState();
}

class _ConversationItemTileState extends State<ConversationItemTile> {
  late String _displayName;
  late String _displayPhoto;
  late String _displayPhone;

  @override
  void initState() {
    super.initState();
    _displayName = widget.chat.otherUserName;
    _displayPhoto = widget.chat.otherUserPhoto;
    _displayPhone = widget.chat.otherUserPhone;

    _resolveUserProfile();
  }

  @override
  void didUpdateWidget(covariant ConversationItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.otherUserId != widget.chat.otherUserId ||
        oldWidget.chat.otherUserName != widget.chat.otherUserName) {
      _displayName = widget.chat.otherUserName;
      _displayPhoto = widget.chat.otherUserPhoto;
      _displayPhone = widget.chat.otherUserPhone;
      _resolveUserProfile();
    }
  }

  Future<void> _resolveUserProfile() async {
    final uid = widget.chat.otherUserId.trim();
    if (uid.isEmpty) return;

    try {
      final profile = await FirebaseRtdbService.getUserProfile(uid);
      if (profile != null && mounted) {
        setState(() {
          final pName = (profile['name'] ?? '').toString().trim();
          if (pName.isNotEmpty && pName != 'User') {
            _displayName = pName;
          }
          final pPhoto = (profile['photoUrl'] ?? '').toString().trim();
          if (pPhoto.isNotEmpty) {
            _displayPhoto = pPhoto;
          }
          final pPhone = (profile['phone'] ?? '').toString().trim();
          if (pPhone.isNotEmpty) {
            _displayPhone = pPhone;
          }
        });
      }
    } catch (_) {}
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays == 0) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;

    // Subtitle formatting: Space Title + Vehicle Model / Number
    final spotAndVehicle = [
      chat.spaceTitle,
      if (chat.vehicleInfo.isNotEmpty && chat.vehicleInfo != 'N/A') chat.vehicleInfo,
    ].where((s) => s.isNotEmpty).join(' • ');

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              partnerId: chat.otherUserId,
              partnerName: _displayName,
              partnerPhotoUrl: _displayPhoto,
              spaceTitle: chat.spaceTitle,
              phone: _displayPhone,
              vehicleInfo: chat.vehicleInfo,
              partnerRole: widget.isPartnerMode ? 'Customer (Seeker)' : 'Parking Space Host',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Contact Avatar with Online Status Badge
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isPartnerMode
                          ? [Colors.blue.shade600, Colors.indigo.shade700]
                          : [AppColors.primary, const Color(0xFF9333EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _displayPhoto.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(_displayPhoto, fit: BoxFit.cover),
                        )
                      : Center(
                          child: Text(
                            _displayName.isNotEmpty
                                ? _displayName.substring(0, 1).toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Conversation Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.isPartnerMode
                                    ? Colors.blue.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.isPartnerMode ? 'Driver' : 'Host',
                                style: TextStyle(
                                  color: widget.isPartnerMode ? Colors.blue.shade700 : AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(chat.lastMessageTime),
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Space & Vehicle Tag
                  if (spotAndVehicle.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            spotAndVehicle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),

                  // Last Message Snippet & Unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: chat.unreadCount > 0 ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
                            fontWeight: chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Quick Call Action Button
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      partnerName: _displayName,
                      partnerPhotoUrl: _displayPhoto,
                      partnerRole: widget.isPartnerMode ? 'Customer (Seeker)' : 'Space Owner',
                      subtitle: spotAndVehicle,
                      phone: _displayPhone,
                    ),
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
