import 'package:flutter/material.dart';
import '../../../../core/utils/addon_icons.dart';
import '../../../../core/utils/extensions.dart';
import '../../../admin/presentation/widgets/product_thumb.dart';

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

    final String name = displayedProduct!['name'] as String;
    final String? imagePath = displayedProduct!['image_path'] as String?;
    final int price = displayedProduct!['price'] as int;
    final int stock = (displayedProduct!['stock'] as int?) ?? 0;
    final List addons = (displayedProduct!['addons'] as List?) ?? const [];

    // حالت عادی (نمایش محصول)
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double size = constraints.biggest.shortestSide;
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: ProductThumb(
                    name: name,
                    imagePath: imagePath,
                    size: size,
                    radius: 16,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            price.toRial,
            style: TextStyle(fontSize: 18, color: Colors.green.shade700, fontWeight: FontWeight.w500),
          ),
        ),
        if (stock > 0 && stock <= 3)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'تنها $stock عدد باقی مانده',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        // افزودنی‌های همراه کالا (انتخاب مشتری نیست؛ فقط اطلاع‌رسانی)
        if (addons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Text('همراه:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                for (final a in addons) _addonChip(a as Map),
              ],
            ),
          ),
        const SizedBox(height: 8),
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

  Widget _addonChip(Map a) {
    final int qty = (a['qty'] as int?) ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AddonIcons.iconFor(a['icon_key'] as String?), size: 14, color: Colors.blueGrey.shade600),
          const SizedBox(width: 4),
          Text(
            '${a['name']}${qty > 1 ? ' ×$qty' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w600),
          ),
        ],
      ),
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