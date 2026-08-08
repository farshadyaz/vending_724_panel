import 'package:flutter/material.dart';

class CheckoutBarWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final VoidCallback? onCheckout;

  const CheckoutBarWidget({
    super.key,
    required this.cart,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final int totalPrice = cart.fold<int>(0, (sum, item) => sum + (item['price'] as int));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('جمع کل سبد:', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$totalPrice ریال',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600), // سایز کوچکتر
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('پرداخت و تحویل', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
            ),
          )
        ],
      ),
    );
  }
}