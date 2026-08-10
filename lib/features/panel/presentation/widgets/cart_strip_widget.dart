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
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () => onRemoveFromCart(cart[index]['id']),
                  child: AspectRatio(
                    aspectRatio: 1, // کاملا مربع و ریسپانسیو
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Icon(Icons.fastfood, color: Colors.blue, size: 40),
                          ),
                        ),
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
                  ),
                ),
              ),
            );
          }
          
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}