import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/chat_conversation.dart';
import '../../shared/models/support_ticket.dart';
import '../../shared/providers/app_providers.dart';
import '../support/support_chat_screen.dart';
import '../support/help_support_screen.dart';
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
  String _activeFilter = 'all'; // 'all' | 'hosts' | 'tickets'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              widget.isPartnerMode ? 'Customer & Support Chats' : 'Messages & Support',
              style: const TextStyle(
                color: AppColors.textPrimaryLight,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              widget.isPartnerMode ? 'Active Customer Comms & Helpdesk' : 'Parking Hosts & Support Tickets',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                        hintText: 'Search host, ticket subject, or vehicle...',
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

          // Filter Category Chips (All Chats, Host Inquiries, Support Tickets)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Chats', Icons.forum_outlined),
                const SizedBox(width: 8),
                _buildFilterChip('hosts', widget.isPartnerMode ? 'Customers' : 'Hosts', Icons.local_parking_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('tickets', 'Support Tickets', Icons.headset_mic_rounded),
              ],
            ),
          ),

          // Combined Stream Builder for Host Conversations & Support Tickets
          Expanded(
            child: StreamBuilder<List<ChatConversation>>(
              stream: ChatService.streamConversations(userId, isPartner: widget.isPartnerMode),
              builder: (context, hostSnap) {
                return StreamBuilder<List<SupportTicket>>(
                  stream: FirebaseRtdbService.streamUserSupportTickets(userId),
                  builder: (context, ticketSnap) {
                    if ((hostSnap.connectionState == ConnectionState.waiting && !hostSnap.hasData) ||
                        (ticketSnap.connectionState == ConnectionState.waiting && !ticketSnap.hasData)) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    final hostChats = hostSnap.data ?? [];
                    final tickets = ticketSnap.data ?? [];

                    // Filter host chats by search query
                    final filteredHosts = hostChats.where((c) {
                      if (_searchQuery.isEmpty) return true;
                      final query = _searchQuery.toLowerCase();
                      return c.otherUserName.toLowerCase().contains(query) ||
                          c.spaceTitle.toLowerCase().contains(query) ||
                          c.spaceAddress.toLowerCase().contains(query) ||
                          c.vehicleInfo.toLowerCase().contains(query) ||
                          c.lastMessage.toLowerCase().contains(query);
                    }).toList();

                    // Filter tickets by search query
                    final filteredTickets = tickets.where((t) {
                      if (_searchQuery.isEmpty) return true;
                      final query = _searchQuery.toLowerCase();
                      return t.subject.toLowerCase().contains(query) ||
                          t.description.toLowerCase().contains(query) ||
                          t.category.toLowerCase().contains(query) ||
                          t.status.toLowerCase().contains(query) ||
                          (t.lastMessage != null && t.lastMessage!.toLowerCase().contains(query));
                    }).toList();

                    // Decide what to render based on active filter
                    final showHosts = _activeFilter == 'all' || _activeFilter == 'hosts';
                    final showTickets = _activeFilter == 'all' || _activeFilter == 'tickets';

                    final totalItems = (showHosts ? filteredHosts.length : 0) + (showTickets ? filteredTickets.length : 0);

                    if (totalItems == 0) {
                      return _buildEmptyState();
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        // Support Tickets Section Header if in "all" mode with both types
                        if (showTickets && filteredTickets.isNotEmpty) ...[
                          if (_activeFilter == 'all' && showHosts && filteredHosts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4, left: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ACTIVE SUPPORT TICKETS',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondaryLight,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    '${filteredTickets.length}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ...filteredTickets.map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildSupportTicketTile(t),
                              )),
                        ],

                        // Host Conversations Section Header if in "all" mode
                        if (showHosts && filteredHosts.isNotEmpty) ...[
                          if (_activeFilter == 'all' && showTickets && filteredTickets.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 8, left: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    widget.isPartnerMode ? 'ACTIVE DRIVER INQUIRIES' : 'ACTIVE HOST CHATS',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondaryLight,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    '${filteredHosts.length}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ...filteredHosts.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ConversationItemTile(
                                  chat: c,
                                  isPartnerMode: widget.isPartnerMode,
                                ),
                              )),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _activeFilter == 'tickets' || _activeFilter == 'all'
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 20),
              label: const Text('Raise Ticket', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String filterKey, String label, IconData icon) {
    final isSelected = _activeFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondaryLight),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportTicketTile(SupportTicket ticket) {
    final statusColor = ticket.statusColor;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(ticket: ticket),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.shade100, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Headset / Shield Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),

            // Ticket Details
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
                                ticket.subject,
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
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Support',
                                style: TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(DateTime.tryParse(ticket.updatedAt ?? ticket.createdAt) ?? DateTime.now()),
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Category & Status Tag Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ticket.statusDisplay.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Category: ${ticket.category.replaceAll('_', ' ')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message preview
                  Text(
                    ticket.lastMessage != null && ticket.lastMessage!.isNotEmpty
                        ? ticket.lastMessage!
                        : ticket.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            // Direct Chat chevron
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF7C3AED), size: 16),
            ),
          ],
        ),
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
              _activeFilter == 'tickets' ? 'No Support Tickets Found' : 'No Active Conversations',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _activeFilter == 'tickets'
                  ? 'You have not raised any support tickets. Click "Raise Ticket" below to chat with an admin.'
                  : (widget.isPartnerMode
                      ? 'Incoming active driver inquiries and booking chats will appear here. Completed booking chats are archived.'
                      : 'Active chats with parking hosts and 24/7 support tickets will appear here. Completed booking chats are archived.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            if (_activeFilter == 'tickets' || _activeFilter == 'all') ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                  );
                },
                icon: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 18),
                label: const Text('Raise Support Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
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
