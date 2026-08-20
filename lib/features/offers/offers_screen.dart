import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/offer.dart';
import '../../shared/providers/app_providers.dart';
import '../search/search_parking_screen.dart';

class OffersBottomSheet extends ConsumerStatefulWidget {
  final bool isBottomSheet;
  const OffersBottomSheet({super.key, this.isBottomSheet = true});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const OffersBottomSheet(isBottomSheet: true),
    );
  }

  @override
  ConsumerState<OffersBottomSheet> createState() => _OffersBottomSheetState();
}

// Alias for backward compatibility if referenced elsewhere
typedef OffersScreen = OffersBottomSheet;

class _OffersBottomSheetState extends ConsumerState<OffersBottomSheet> {
  String _selectedCategory = 'all';
  String? _copiedCode;

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copiedCode = code);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Coupon "$code" copied to clipboard!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiedCode = null);
    });
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF7C3AED);
  }

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(offersStreamProvider);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isBottomSheet) ...[
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Exclusive Offers & Promos',
                      style: TextStyle(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],

        // Category Filter Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('all', 'All Offers'),
                const SizedBox(width: 8),
                _buildCategoryChip('first_booking', 'First Booking'),
                const SizedBox(width: 8),
                _buildCategoryChip('weekend', 'Weekend Deals'),
                const SizedBox(width: 8),
                _buildCategoryChip('ev', 'EV Charging'),
              ],
            ),
          ),
        ),

        // Offers List Container
        Flexible(
          child: offersAsync.when(
            data: (allOffers) {
              final displayOffers = allOffers.isNotEmpty
                  ? allOffers
                  : [
                      Offer(
                        id: 'FIRST50',
                        code: 'FIRST50',
                        title: '50% OFF First Booking',
                        description: 'Get 50% discount up to ₹100 on your first parking reservation.',
                        discountType: 'percentage',
                        discountValue: 50,
                        maxDiscount: 100,
                        minBookingAmount: 50,
                        category: 'first_booking',
                        isActive: true,
                        color: '#7C3AED',
                        createdAt: DateTime.now(),
                      ),
                      Offer(
                        id: 'WEEKEND20',
                        code: 'WEEKEND20',
                        title: '20% OFF Weekend Parking',
                        description: 'Save 20% on all Saturday & Sunday parking spot bookings.',
                        discountType: 'percentage',
                        discountValue: 20,
                        maxDiscount: 150,
                        minBookingAmount: 100,
                        category: 'weekend',
                        isActive: true,
                        color: '#2563EB',
                        createdAt: DateTime.now(),
                      ),
                      Offer(
                        id: 'EVFAST50',
                        code: 'EVFAST50',
                        title: '₹50 Flat OFF EV Charging',
                        description: 'Flat ₹50 discount on EV charging enabled parking spaces.',
                        discountType: 'flat',
                        discountValue: 50,
                        minBookingAmount: 150,
                        category: 'ev',
                        isActive: true,
                        color: '#059669',
                        createdAt: DateTime.now(),
                      ),
                    ];

              final filtered = displayOffers.where((offer) {
                if (!offer.isActive) return false;
                if (_selectedCategory == 'all') return true;
                return offer.category == _selectedCategory;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No Active Offers in this Category',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Check back later for seasonal discounts and promotional parking codes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: widget.isBottomSheet,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final offer = filtered[index];
                  return _buildOfferCard(offer);
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text('Failed to load offers.', style: TextStyle(color: Colors.grey.shade600)),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.isBottomSheet) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Exclusive Offers',
              style: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: content,
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label) {
    final isSelected = _selectedCategory == categoryKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = categoryKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(Offer offer) {
    final primaryColor = _parseHexColor(offer.color);
    final isCopied = _copiedCode == offer.code;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner with gradient
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              offer.category.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (offer.discountType == 'percentage')
                            Text(
                              '${offer.discountValue.toInt()}% OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            )
                          else
                            Text(
                              '₹${offer.discountValue.toInt()} FLAT OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        offer.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Coupon Code Box + Copy Action
                GestureDetector(
                  onTap: () => _copyToClipboard(offer.code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          offer.code,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isCopied ? Icons.check_circle : Icons.copy_rounded,
                          size: 14,
                          color: isCopied ? const Color(0xFF10B981) : primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondaryLight,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),

                // Specs Line
                Row(
                  children: [
                    if (offer.minBookingAmount > 0) ...[
                      Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Min spend: ₹${offer.minBookingAmount.toInt()}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (offer.maxDiscount != null) ...[
                      Icon(Icons.arrow_upward_rounded, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Max saving: ₹${offer.maxDiscount!.toInt()}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Action: Apply on Booking
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _copyToClipboard(offer.code);
                      if (widget.isBottomSheet) {
                        Navigator.of(context).pop();
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
                      );
                    },
                    icon: const Icon(Icons.directions_car_filled_outlined, size: 16),
                    label: const Text('Copy Code & Find Parking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
