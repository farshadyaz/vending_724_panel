import 'package:flutter/material.dart';

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
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(maxCartCapacity, (index) {
          if (index < cart.length) {
            return GestureDetector(
              // لمس کل این بخش (عکس یا آیکون) باعث حذف کالا می‌شود
              onTap: () => onRemoveFromCart(cart[index]['id']),
              child: Stack(
                clipBehavior: Clip.none, // اجازه می‌دهد آیکون کمی از کادر بیرون بزند
                children: [
                  // باکس اصلی تصویر کالا
                  Container(
                    width: 70, 
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: const Icon(Icons.fastfood, color: Colors.blue, size: 30),
                  ),
                  // آیکون ضربدر قرمز (Badge) در بالا سمت چپ
                  Positioned(
                    top: -5,
                    left: -5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            );
          }
          
          // جایگاه خالی سبد خرید
          return Container(
            width: 70, 
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            ),
          );
        }),
      ),
    );
  }
}