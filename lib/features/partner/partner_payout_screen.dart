import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/firebase_rtdb_service.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/partner_payout_record.dart';
import '../../shared/providers/app_providers.dart';

class PartnerPayoutScreen extends ConsumerStatefulWidget {
  const PartnerPayoutScreen({super.key});

  @override
  ConsumerState<PartnerPayoutScreen> createState() => _PartnerPayoutScreenState();
}

class _PartnerPayoutScreenState extends ConsumerState<PartnerPayoutScreen> {
  final _holderCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _accCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;
  bool _hasSavedDetails = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadPayoutDetails();
  }

  Future<void> _loadPayoutDetails() async {
    final user = ref.read(userProfileProvider);
    if (user.uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final snap = await FirebaseRtdbService.db.ref('users/${user.uid}/payoutDetails').get();
      if (snap.value != null && snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        _holderCtrl.text = data['holderName']?.toString() ?? user.name;
        _bankCtrl.text = data['bankName']?.toString() ?? '';
        _accCtrl.text = data['accountNumber']?.toString() ?? '';
        _ifscCtrl.text = data['ifscCode']?.toString() ?? '';
        _upiCtrl.text = data['upiId']?.toString() ?? '';
        _hasSavedDetails = _accCtrl.text.isNotEmpty || _upiCtrl.text.isNotEmpty;
        _isEditing = !_hasSavedDetails;
      } else {
        _holderCtrl.text = user.name;
        _hasSavedDetails = false;
        _isEditing = true;
      }
    } catch (_) {
      _holderCtrl.text = user.name;
      _hasSavedDetails = false;
      _isEditing = true;
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _bankCtrl.dispose();
    _accCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePayoutDetails() async {
    final user = ref.read(userProfileProvider);
    if (user.uid.isEmpty) return;

    if (_accCtrl.text.trim().isEmpty && _upiCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least an Account Number or UPI ID.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseRtdbService.db.ref('users/${user.uid}/payoutDetails').set({
        'holderName': _holderCtrl.text.trim(),
        'bankName': _bankCtrl.text.trim(),
        'accountNumber': _accCtrl.text.trim(),
        'ifscCode': _ifscCtrl.text.trim().toUpperCase(),
        'upiId': _upiCtrl.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        setState(() {
          _hasSavedDetails = true;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank Payout details saved securely!'), backgroundColor: AppColors.greenSuccess),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save details: $e'), backgroundColor: AppColors.redError),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _maskAccountNumber(String acc) {
    if (acc.isEmpty) return '';
    if (acc.length <= 4) return acc;
    final last4 = acc.substring(acc.length - 4);
    return '•••• •••• •••• $last4';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$min $ampm';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Bank & Payout Setup', style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : StreamBuilder<List<Booking>>(
              stream: FirebaseRtdbService.streamPartnerBookings(user.uid),
              builder: (context, bookingsSnap) {
                final bookings = bookingsSnap.data ?? <Booking>[];
                final totalEarnings = bookings.fold<double>(0.0, (sum, b) => sum + b.totalAmount);

                return StreamBuilder<List<PartnerPayoutRecord>>(
                  stream: FirebaseRtdbService.streamPartnerPayouts(user.uid),
                  builder: (context, payoutsSnap) {
                    final payouts = payoutsSnap.data ?? <PartnerPayoutRecord>[];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Real Available Payout Balance Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 14,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Available Payout Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                const SizedBox(height: 6),
                                Text('₹${totalEarnings.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (totalEarnings <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No balance available for payout yet.')),
                                      );
                                      return;
                                    }
                                    if (!_hasSavedDetails) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please save your Bank Account or UPI ID below first.')),
                                      );
                                      return;
                                    }

                                    try {
                                      await FirebaseRtdbService.db.ref('users/${user.uid}/payoutRequests').push().set({
                                        'amount': totalEarnings,
                                        'bankName': _bankCtrl.text.trim(),
                                        'accountNumber': _accCtrl.text.trim(),
                                        'upiId': _upiCtrl.text.trim(),
                                        'requestedAt': DateTime.now().toIso8601String(),
                                        'status': 'processing',
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Instant payout request of ₹${totalEarnings.toStringAsFixed(0)} submitted successfully!'),
                                            backgroundColor: AppColors.greenSuccess,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Payout request failed: $e')),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Request Instant Payout', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Bank Details Section: Saved Card vs Editable Form
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Bank Account Details',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                              ),
                              if (_hasSavedDetails && !_isEditing)
                                TextButton.icon(
                                  onPressed: () => setState(() => _isEditing = true),
                                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                  label: const Text('Edit', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (_hasSavedDetails && !_isEditing)
                            _buildSavedBankCard()
                          else
                            _buildBankEditForm(),

                          const SizedBox(height: 30),

                          // Section: Payout History from Admin Panel
                          Row(
                            children: [
                              const Text(
                                'Payout History & Settlements',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${payouts.length}',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Payouts dispatched by MeeParking admin panel will be reflected here.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 14),

                          if (payouts.isEmpty)
                            _buildEmptyPayoutsCard()
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: payouts.length,
                              itemBuilder: (context, index) {
                                final payout = payouts[index];
                                return _buildPayoutHistoryCard(payout);
                              },
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  // Card View of Saved Bank Details
  Widget _buildSavedBankCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bankCtrl.text.isNotEmpty ? _bankCtrl.text : 'Bank Account',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Text(
                        'Active Payout Destination',
                        style: TextStyle(fontSize: 11, color: AppColors.greenSuccess, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.greenSuccess.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.greenSuccess.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 13, color: AppColors.greenSuccess),
                    SizedBox(width: 4),
                    Text('Verified', style: TextStyle(color: AppColors.greenSuccess, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildSavedDetailRow(Icons.person_outline, 'Account Holder', _holderCtrl.text),
          if (_accCtrl.text.isNotEmpty)
            _buildSavedDetailRow(Icons.numbers, 'Account Number', _maskAccountNumber(_accCtrl.text)),
          if (_ifscCtrl.text.isNotEmpty)
            _buildSavedDetailRow(Icons.qr_code_scanner, 'IFSC Code', _ifscCtrl.text),
          if (_upiCtrl.text.isNotEmpty)
            _buildSavedDetailRow(Icons.alternate_email, 'UPI ID', _upiCtrl.text),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
            label: const Text('Update Bank Details', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondaryLight),
          const SizedBox(width: 8),
          Text('$label:', style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }

  // Editable Form for Bank Details
  Widget _buildBankEditForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _holderCtrl,
            decoration: const InputDecoration(
              labelText: 'Account Holder Name',
              prefixIcon: Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bankCtrl,
            decoration: const InputDecoration(
              labelText: 'Bank Name (e.g. HDFC Bank, SBI)',
              prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Account Number',
              prefixIcon: Icon(Icons.pin_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ifscCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'IFSC Code',
              prefixIcon: Icon(Icons.business_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _upiCtrl,
            decoration: const InputDecoration(
              labelText: 'UPI ID (e.g. yourname@upi)',
              prefixIcon: Icon(Icons.alternate_email, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (_hasSavedDetails) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePayoutDetails,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Bank Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Payout History Item Card
  Widget _buildPayoutHistoryCard(PartnerPayoutRecord payout) {
    final statusLower = payout.status.toLowerCase();
    final bool isPaid = statusLower == 'paid' || statusLower == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid ? AppColors.greenSuccess.withOpacity(0.12) : AppColors.orangeWarning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isPaid ? Icons.check_circle : Icons.hourglass_top, size: 13, color: isPaid ? AppColors.greenSuccess : AppColors.orangeWarning),
                    const SizedBox(width: 4),
                    Text(
                      payout.status.toUpperCase(),
                      style: TextStyle(
                        color: isPaid ? AppColors.greenSuccess : AppColors.orangeWarning,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(payout.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payout.paymentMode.isNotEmpty ? payout.paymentMode : 'Bank Transfer',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (payout.transactionRef.isNotEmpty)
                    Text(
                      'Ref: ${payout.transactionRef}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                ],
              ),
              Text(
                '+ ₹${payout.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.greenSuccess,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Dispatched by: ${payout.adminName}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          if (payout.adminNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Remarks: ${payout.adminNotes}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // Empty State for Payout History
  Widget _buildEmptyPayoutsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3E8FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Payouts Received Yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
          ),
          const SizedBox(height: 6),
          const Text(
            'When the admin panel releases payouts for your parking earnings, your payout settlement records will appear here in real-time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4),
          ),
        ],
      ),
    );
  }
}
