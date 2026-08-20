import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import 'partner_onboarding_wizard.dart';

class BecomePartnerScreen extends ConsumerStatefulWidget {
  const BecomePartnerScreen({super.key});

  @override
  ConsumerState<BecomePartnerScreen> createState() => _BecomePartnerScreenState();
}

class _BecomePartnerScreenState extends ConsumerState<BecomePartnerScreen> {
  // Earnings Calculator State
  double _numSpots = 3.0;
  double _hourlyRate = 30.0;
  double _hoursPerDay = 8.0;
  String _selectedVehicleType = 'car'; // 'car' | 'bike' | 'ev'

  // FAQ Expanded State
  final Map<int, bool> _expandedFaqs = {0: true};

  double get _vehicleMultiplier {
    switch (_selectedVehicleType) {
      case 'bike':
        return 0.5;
      case 'ev':
        return 1.4; // EV charging spots earn higher rate
      case 'car':
      default:
        return 1.0;
    }
  }

  int get _calculatedMonthlyEarnings {
    final daily = _numSpots * (_hourlyRate * _vehicleMultiplier) * _hoursPerDay;
    return (daily * 30).round();
  }

  int get _calculatedYearlyEarnings {
    return _calculatedMonthlyEarnings * 12;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Become a Partner',
          style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryLight, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x337C3AED),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Turn Empty Parking\nInto Daily Income',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'List residential, commercial, or plot spaces in under 2 minutes. Receive automatic bookings & direct payouts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Interactive Monthly Earnings Calculator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interactive Earnings Estimator',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Adjust sliders to estimate your potential income',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Vehicle Type Selector Chips
                    Row(
                      children: [
                        _buildVehicleChip('Cars', 'car', Icons.directions_car_outlined),
                        const SizedBox(width: 8),
                        _buildVehicleChip('Bikes', 'bike', Icons.two_wheeler_outlined),
                        const SizedBox(width: 8),
                        _buildVehicleChip('EV Spots ⚡', 'ev', Icons.electric_car_outlined),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Slider 1: Number of Spots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available Spots', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          '${_numSpots.toInt()} ${_numSpots.toInt() == 1 ? 'Slot' : 'Slots'}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.purple.shade50,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withOpacity(0.12),
                      ),
                      child: Slider(
                        value: _numSpots,
                        min: 1.0,
                        max: 20.0,
                        divisions: 19,
                        onChanged: (val) => setState(() => _numSpots = val),
                      ),
                    ),

                    // Slider 2: Rate per Hour
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hourly Rate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          '₹${_hourlyRate.toInt()} / hr',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.purple.shade50,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withOpacity(0.12),
                      ),
                      child: Slider(
                        value: _hourlyRate,
                        min: 10.0,
                        max: 100.0,
                        divisions: 18,
                        onChanged: (val) => setState(() => _hourlyRate = val),
                      ),
                    ),

                    // Slider 3: Occupied Hours Per Day
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Occupied Hours / Day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          '${_hoursPerDay.toInt()} hrs',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.purple.shade50,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withOpacity(0.12),
                      ),
                      child: Slider(
                        value: _hoursPerDay,
                        min: 2.0,
                        max: 16.0,
                        divisions: 14,
                        onChanged: (val) => setState(() => _hoursPerDay = val),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Result Highlight Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimated Earnings',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B21A8), fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹ ${_formatCurrency(_calculatedMonthlyEarnings)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF581C87),
                                ),
                              ),
                              const Text(
                                '/ month',
                                style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE)),
                              ),
                            ],
                          ),
                          Container(
                            height: 44,
                            width: 1,
                            color: const Color(0xFFDDD6FE),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Annual Potential',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B21A8), fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹ ${_formatCurrency(_calculatedYearlyEarnings)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.greenSuccess,
                                ),
                              ),
                              const Text(
                                '/ year',
                                style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4-Step Onboarding Interactive Process
              const Text(
                'How Onboarding Works',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildStepCard(
                stepNum: '1',
                title: 'Draw Parking Area on Map',
                subtitle: 'Tap to mark exact boundary polygon coordinates and set your address.',
                icon: Icons.map_outlined,
                iconColor: Colors.blue,
              ),
              const SizedBox(height: 10),
              _buildStepCard(
                stepNum: '2',
                title: 'Add Capacity & Amenities',
                subtitle: 'Specify number of car & bike slots, CCTV surveillance, covered parking, and EV chargers.',
                icon: Icons.local_parking_rounded,
                iconColor: Colors.teal,
              ),
              const SizedBox(height: 10),
              _buildStepCard(
                stepNum: '3',
                title: 'Upload Space Photos',
                subtitle: 'Take clear pictures of your parking entrance and spots for verified seekers.',
                icon: Icons.camera_alt_outlined,
                iconColor: Colors.amber.shade800,
              ),
              const SizedBox(height: 10),
              _buildStepCard(
                stepNum: '4',
                title: 'Set Rates & Go Live',
                subtitle: 'Configure hourly, daily, and monthly rates. Your space goes live immediately!',
                icon: Icons.rocket_launch_outlined,
                iconColor: AppColors.greenSuccess,
              ),
              const SizedBox(height: 24),

              // Interactive FAQ Section
              const Text(
                'Frequently Asked Questions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildFaqItem(
                index: 0,
                question: 'How do I receive payments for bookings?',
                answer:
                    'Earnings from completed bookings are automatically calculated and can be withdrawn directly to your bank account or UPI at any time with 0% processing delays.',
              ),
              const SizedBox(height: 8),
              _buildFaqItem(
                index: 1,
                question: 'Can I choose when my parking space is open?',
                answer:
                    'Yes! In your Partner Dashboard, you have full control to toggle your listing online/offline, set specific operating hours, or block specific dates anytime.',
              ),
              const SizedBox(height: 8),
              _buildFaqItem(
                index: 2,
                question: 'What kind of parking spaces can I list?',
                answer:
                    'You can list private residential driveways, vacant plots, commercial basements, office parking decks, or dedicated EV charging slots.',
              ),
              const SizedBox(height: 28),

              // Bottom CTA Button "List Your Parking Space"
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PartnerOnboardingWizard(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white, size: 20),
                  label: const Text(
                    'List Your Parking Space Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleChip(String label, String key, IconData icon) {
    final bool isSelected = _selectedVehicleType == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedVehicleType = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNum,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'STEP $stepNum',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFaqItem({
    required int index,
    required String question,
    required String answer,
  }) {
    final bool isExpanded = _expandedFaqs[index] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (val) => setState(() => _expandedFaqs[index] = val),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Text(
            question,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Text(
                answer,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)} L';
    }
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
