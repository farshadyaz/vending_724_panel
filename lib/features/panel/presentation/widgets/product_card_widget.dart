import 'package:flutter/material.dart';

class ProductCardWidget extends StatelessWidget {
  final Map<String, dynamic>? displayedProduct;
  final bool isSearching;
  final int cartLength;
  final int maxCartCapacity;
  final VoidCallback onAddToCart;

  const ProductCardWidget({
    super.key,
    required this.displayedProduct,
    required this.isSearching,
    required this.cartLength,
    required this.maxCartCapacity,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 15, spreadRadius: 2)],
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // نمایش اسکلتون در زمان جستجو یا وارد نشدن شماره رک
    if (isSearching || displayedProduct == null) {
      return _buildSkeleton();
    }

    // حالت خطا: حذف اسکلتون و نمایش پیام بدون بک‌گراند
    if (displayedProduct!.containsKey('error')) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 65),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayedProduct!['error'],
              style: TextStyle(fontSize: 20, color: Colors.red.shade600, fontWeight: FontWeight.w600),
            ),
          )
        ],
      );
    }

    // حالت عادی (نمایش محصول)
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Icon(displayedProduct!['image'], size: 70, color: Colors.blue.shade700),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            displayedProduct!['name'], 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${displayedProduct!['price']} ریال', 
            style: TextStyle(fontSize: 18, color: Colors.green.shade700, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: displayedProduct!['status'] == true && cartLength < maxCartCapacity ? onAddToCart : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.blue,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                cartLength >= maxCartCapacity ? 'سبد پر است' : 'افزودن به سبد',
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        )
      ],
    );
  }

  // ساختار اسکلتونی
  Widget _buildSkeleton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
        ),
        Container(
          width: 120, height: 24,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        ),
        Container(
          width: 90, height: 20,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        ),
        Container(
          width: double.infinity, height: 45,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        ),
      ],
    );
  }
}