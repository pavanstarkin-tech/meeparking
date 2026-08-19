import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    Icons.headset_mic_outlined,
                    'Toll-Free Call',
                    '1800-MEE-PARK',
                    AppColors.primary,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dialing Support Hotline 1800-MEE-PARK...')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactCard(
                    Icons.chat_bubble_outline,
                    'Live Chat',
                    'Chat with Agent',
                    AppColors.greenSuccess,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connecting to Support Live Chat Agent...')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Frequently Asked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildFaqTile('How do I navigate to my booked parking spot?', 'Once your booking is confirmed, open your booking card and tap "Navigate" to get real-time turn-by-turn GPS directions.'),
            _buildFaqTile('When does wallet deduction occur?', 'Wallet balance is deducted ONLY AFTER your parking reservation is successfully saved and confirmed in our database.'),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
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
