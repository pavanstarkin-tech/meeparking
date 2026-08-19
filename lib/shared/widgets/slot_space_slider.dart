import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SlotSpaceSlider extends StatefulWidget {
  final List<String> images;
  final double height;
  final BoxFit fit;

  const SlotSpaceSlider({
    super.key,
    required this.images,
    this.height = 240,
    this.fit = BoxFit.cover,
  });

  @override
  State<SlotSpaceSlider> createState() => _SlotSpaceSliderState();
}

class _SlotSpaceSliderState extends State<SlotSpaceSlider> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validImages = widget.images.isNotEmpty
        ? widget.images
        : ['https://images.unsplash.com/photo-1506521781263-d8422e82f27a?auto=format&fit=crop&w=800&q=80'];

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: validImages.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final url = validImages[index];
              return Image.network(
                url,
                fit: widget.fit,
                width: double.infinity,
                height: widget.height,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primaryDark,
                  child: const Center(
                    child: Icon(Icons.local_parking, size: 64, color: Colors.white),
                  ),
                ),
              );
            },
          ),
          if (validImages.length > 1)
            Positioned(
              bottom: 12,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      '${_currentIndex + 1}/${validImages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (validImages.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(validImages.length, (idx) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == idx ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == idx ? Colors.white : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
