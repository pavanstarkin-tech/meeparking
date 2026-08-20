import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/support_ticket.dart';
import '../../shared/providers/app_providers.dart';
import 'support_chat_screen.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _IssueOption {
  final String title;
  final String priority; // 'urgent' | 'high' | 'medium' | 'low'
  final String defaultDescription;

  const _IssueOption({
    required this.title,
    required this.priority,
    required this.defaultDescription,
  });
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  static const Map<String, List<_IssueOption>> _issueCatalog = {
    'booking': [
      _IssueOption(
        title: 'Spot occupied by another vehicle',
        priority: 'urgent',
        defaultDescription: 'I arrived at the reserved parking space, but another vehicle is parked in my assigned spot.',
      ),
      _IssueOption(
        title: 'Gate / Barrier locked & host unreachable',
        priority: 'urgent',
        defaultDescription: 'The entrance gate/barrier is locked and the parking space host is not answering calls or messages.',
      ),
      _IssueOption(
        title: 'Unable to reach / inaccurate location',
        priority: 'high',
        defaultDescription: 'The map navigation coordinates were inaccurate or vehicle access was blocked to the designated spot.',
      ),
      _IssueOption(
        title: 'Extend booking duration / timing conflict',
        priority: 'medium',
        defaultDescription: 'I need assistance extending my current parking session or resolving a schedule overlap.',
      ),
      _IssueOption(
        title: 'Other booking or spot dispute',
        priority: 'medium',
        defaultDescription: 'Inquiry regarding my active/upcoming parking reservation.',
      ),
    ],
    'payment': [
      _IssueOption(
        title: 'Payment deducted twice / double charged',
        priority: 'high',
        defaultDescription: 'Money was deducted more than once from my bank account/UPI for this reservation.',
      ),
      _IssueOption(
        title: 'Money debited but booking not confirmed',
        priority: 'high',
        defaultDescription: 'My payment was deducted via UPI/Razorpay but the app did not generate a booking confirmation.',
      ),
      _IssueOption(
        title: 'Refund not credited to wallet / bank',
        priority: 'high',
        defaultDescription: 'My cancelled booking refund has not yet appeared in my MeeParking wallet balance.',
      ),
      _IssueOption(
        title: 'Promo coupon / offer discount not applied',
        priority: 'low',
        defaultDescription: 'The eligible promotional coupon was not deducted from my final booking total.',
      ),
      _IssueOption(
        title: 'Other billing / receipt inquiry',
        priority: 'medium',
        defaultDescription: 'Question about transaction receipt or parking charges.',
      ),
    ],
    'space': [
      _IssueOption(
        title: 'Host demanded extra cash / off-app fee',
        priority: 'high',
        defaultDescription: 'The space owner or attendant demanded unauthorized cash payment on arrival.',
      ),
      _IssueOption(
        title: 'Vehicle safety / premise damage incident',
        priority: 'urgent',
        defaultDescription: 'There was a safety hazard, damage, or security concern at the parking space premise.',
      ),
      _IssueOption(
        title: 'Promised amenities missing (No EV / CCTV)',
        priority: 'medium',
        defaultDescription: 'The space listing listed EV charging or CCTV, but the facility was missing or non-functional.',
      ),
      _IssueOption(
        title: 'Unprofessional host behavior',
        priority: 'medium',
        defaultDescription: 'The space host was uncooperative or disrespectful during my parking check-in.',
      ),
    ],
    'account': [
      _IssueOption(
        title: 'Vehicle registration / number plate update',
        priority: 'medium',
        defaultDescription: 'Requesting assistance updating registered vehicle license plate or car/bike model.',
      ),
      _IssueOption(
        title: 'Profile phone / email update issue',
        priority: 'low',
        defaultDescription: 'Need assistance updating verified contact details linked to my profile account.',
      ),
      _IssueOption(
        title: 'Technical app glitch or map issue',
        priority: 'low',
        defaultDescription: 'Encountered a technical bug or map rendering issue in the MeeParking application.',
      ),
    ],
    'general': [
      _IssueOption(
        title: 'Host partnership / listing space question',
        priority: 'low',
        defaultDescription: 'Question about listing my private driveway or commercial space on MeeParking.',
      ),
      _IssueOption(
        title: 'General feedback or feature suggestion',
        priority: 'low',
        defaultDescription: 'Suggestions to enhance the parking search and driver experience.',
      ),
    ],
  };

  void _showRaiseTicketSheet(BuildContext context) {
    String selectedCategory = 'booking';
    int selectedSubIndex = 0;
    final subjectCtrl = TextEditingController(text: _issueCatalog['booking']![0].title);
    final descCtrl = TextEditingController(text: _issueCatalog['booking']![0].defaultDescription);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final subIssues = _issueCatalog[selectedCategory] ?? _issueCatalog['booking']!;
          if (selectedSubIndex >= subIssues.length) {
            selectedSubIndex = 0;
          }
          final currentSubIssue = subIssues[selectedSubIndex];
          final dynamicPriority = currentSubIssue.priority;

          Color getPriorityColor(String priority) {
            switch (priority) {
              case 'urgent':
                return const Color(0xFFEF4444); // Red
              case 'high':
                return const Color(0xFFF97316); // Orange
              case 'medium':
                return const Color(0xFFF59E0B); // Amber
              case 'low':
              default:
                return const Color(0xFF3B82F6); // Blue
            }
          }

          String getPriorityLabel(String priority) {
            switch (priority) {
              case 'urgent':
                return 'URGENT (Immediate Support)';
              case 'high':
                return 'HIGH (Priority Handling)';
              case 'medium':
                return 'MEDIUM (Standard Resolution)';
              case 'low':
              default:
                return 'LOW (General Inquiry)';
            }
          }

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Raise a Support Ticket',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Text(
                    'Select your issue category & specific problem to get immediate help.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 16),

                  // 1. Issue Category Selector
                  const Text('1. Select Issue Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.category_outlined, size: 20, color: AppColors.primary),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'booking', child: Text('🚗 Booking & Parking Issues')),
                      DropdownMenuItem(value: 'payment', child: Text('💳 Payments, Refunds & Wallet')),
                      DropdownMenuItem(value: 'space', child: Text('🚫 Space & Host Disputes')),
                      DropdownMenuItem(value: 'account', child: Text('👤 Account & Vehicles')),
                      DropdownMenuItem(value: 'general', child: Text('💬 General Inquiries')),
                    ],
                    onChanged: (val) {
                      if (val != null && val != selectedCategory) {
                        setSheetState(() {
                          selectedCategory = val;
                          selectedSubIndex = 0;
                          final newSub = (_issueCatalog[val] ?? _issueCatalog['booking']!)[0];
                          subjectCtrl.text = newSub.title;
                          descCtrl.text = newSub.defaultDescription;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Dynamic Sub-Issue Selector
                  const Text('2. Specific Sub-Issue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedSubIndex,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.report_problem_outlined, size: 20, color: Color(0xFFF59E0B)),
                    ),
                    items: List.generate(subIssues.length, (idx) {
                      final item = subIssues[idx];
                      return DropdownMenuItem<int>(
                        value: idx,
                        child: Text(
                          item.title,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                    onChanged: (newIdx) {
                      if (newIdx != null) {
                        setSheetState(() {
                          selectedSubIndex = newIdx;
                          final selected = subIssues[newIdx];
                          subjectCtrl.text = selected.title;
                          descCtrl.text = selected.defaultDescription;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Auto-Assigned Priority Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: getPriorityColor(dynamicPriority).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getPriorityColor(dynamicPriority).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          dynamicPriority == 'urgent' ? Icons.warning_amber_rounded : Icons.bolt_rounded,
                          color: getPriorityColor(dynamicPriority),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Auto-Assigned Priority: ',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    getPriorityLabel(dynamicPriority),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: getPriorityColor(dynamicPriority),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dynamicPriority == 'urgent'
                                    ? 'Immediate live escalation to support admin.'
                                    : 'Routed to dedicated queue based on issue severity.',
                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Subject / Title
                  const Text('3. Subject Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: subjectCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Description
                  const Text('4. Provide Extra Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Include parking spot name, booking ID, or photos description...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final subject = subjectCtrl.text.trim();
                              final desc = descCtrl.text.trim();

                              if (subject.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please provide a ticket subject')),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              final user = ref.read(userProfileProvider);

                              final ticket = SupportTicket(
                                id: '',
                                userId: user.uid.isNotEmpty ? user.uid : 'user_01',
                                userName: user.name.isNotEmpty ? user.name : 'Customer',
                                userEmail: user.email,
                                userPhone: user.phone,
                                userRole: user.role.isNotEmpty ? user.role : 'user',
                                subject: subject,
                                description: desc.isNotEmpty ? desc : subject,
                                category: selectedCategory,
                                status: 'open',
                                priority: dynamicPriority,
                                createdAt: DateTime.now().toIso8601String(),
                              );

                              final newTicketId = await FirebaseRtdbService.createSupportTicket(ticket);
                              final createdTicket = SupportTicket(
                                id: newTicketId,
                                userId: ticket.userId,
                                userName: ticket.userName,
                                userEmail: ticket.userEmail,
                                userPhone: ticket.userPhone,
                                userRole: ticket.userRole,
                                subject: ticket.subject,
                                description: ticket.description,
                                category: ticket.category,
                                status: ticket.status,
                                priority: ticket.priority,
                                createdAt: ticket.createdAt,
                              );

                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SupportChatScreen(ticket: createdTicket),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Submit Ticket & Start Live Chat',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(userSupportTicketsStreamProvider);
    final tickets = ticketsAsync.asData?.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Help & Support 24/7', style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Support Options
            Row(
              children: [
                Expanded(
                  child: _buildContactCard(
                    Icons.add_comment_outlined,
                    'Raise Ticket',
                    'Direct to Admin',
                    AppColors.primary,
                    () => _showRaiseTicketSheet(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildContactCard(
                    Icons.chat_bubble_outline,
                    'Live Chat',
                    '24/7 Agent',
                    AppColors.greenSuccess,
                    () {
                      if (tickets.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SupportChatScreen(ticket: tickets.first)),
                        );
                      } else {
                        _showRaiseTicketSheet(context);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildContactCard(
                    Icons.headset_mic_outlined,
                    'Call Us',
                    '1800-MEE-PARK',
                    Colors.orange.shade700,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dialing Support Hotline 1800-MEE-PARK (24x7)...')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // My Support Tickets Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Support Tickets & Disputes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => _showRaiseTicketSheet(context),
                  child: const Text(
                    '+ Raise New',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (ticketsAsync.isLoading && tickets.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (tickets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade400, size: 36),
                    const SizedBox(height: 8),
                    const Text('No Active Support Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text(
                      'Have an issue with parking, payment, or space owner? Tap "+ Raise New" to start a live support chat with admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              )
            else
              ...tickets.map((ticket) {
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SupportChatScreen(ticket: ticket)),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ticket.statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ticket.statusDisplay,
                                style: TextStyle(
                                  color: ticket.statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Text(
                              'Priority: ${ticket.priority.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: ticket.priority == 'urgent' ? Colors.red : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket.subject,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.lastMessage != null && ticket.lastMessage!.isNotEmpty
                              ? ticket.lastMessage!
                              : ticket.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ticket #${ticket.id.length > 8 ? ticket.id.substring(ticket.id.length - 6).toUpperCase() : ticket.id}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            const Row(
                              children: [
                                Text(
                                  'Live Chat',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 11, color: AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),

            const Text('Frequently Asked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildFaqTile('How do I navigate to my booked parking spot?', 'Once your booking is confirmed, open your booking card and tap "Navigate" to get real-time turn-by-turn GPS directions.'),
            _buildFaqTile('When does refund or compensation take effect?', 'When admin resolves a dispute or approves a refund in support ticket management, funds are credited instantly.'),
            _buildFaqTile('How do I contact the parking spot owner?', 'For active or upcoming bookings, you can tap the Call or Chat buttons directly on your booking card.'),
            _buildFaqTile('How do partners receive earnings payout?', 'Partners can set up their bank account or UPI ID in the Partner Payout screen and request instant payouts anytime.'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            CircleAvatar(radius: 18, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqTile(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.primary,
          title: Text(q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
              child: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
