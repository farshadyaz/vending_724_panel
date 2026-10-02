import 'package:flutter/material.dart';
import '../../../admin/presentation/widgets/product_thumb.dart';

class CartStripWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final int maxCartCapacity;
  final Function(String) onRemoveFromCart;

  const CartStripWidget({
    super.key,
    required this.cart,
    required this.maxCartCapacity,
    required this.onRemoveFromCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double gap = 8;
          // اندازه هر خانه: همیشه مربع؛ هم از عرض و هم از ارتفاع نوار بیشتر نمی‌شود
          final double side = ((constraints.maxWidth - gap * maxCartCapacity) / maxCartCapacity)
              .clamp(0.0, constraints.maxHeight)
              .toDouble();

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(maxCartCapacity, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: gap / 2),
                child: SizedBox(
                  width: side,
                  height: side,
                  child: index < cart.length ? _filledSlot(cart[index], side) : _emptySlot(),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _filledSlot(Map<String, dynamic> item, double side) {
    final bool small = side < 50;
    return GestureDetector(
      onTap: () => onRemoveFromCart(item['id']),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ProductThumb(
                name: (item['name'] ?? '').toString(),
                imagePath: item['image_path'] as String?,
                size: side,
              ),
            ),
          ),
          Positioned(
            top: -5,
            left: -5,
            child: Container(
              padding: EdgeInsets.all(small ? 2 : 4),
              decoration: BoxDecoration(
                color: Colors.red.shade500,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.close, color: Colors.white, size: small ? 10 : 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySlot() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
    );
  }
}