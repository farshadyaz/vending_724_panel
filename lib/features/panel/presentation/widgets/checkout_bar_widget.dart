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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('جمع کل سبد:', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$totalPrice ریال',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: onCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('پرداخت و تحویل', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}