import 'package:flutter/material.dart';

class GuideWidget extends StatelessWidget {
  const GuideWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGuideStep(Icons.dialpad, '۱. انتخاب کالا', 'شماره رک را وارد کنید'),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.amber),
          // تغییر متن در این بخش تا کاربر متوجه امکان افزودن چندتایی بشود
          _buildGuideStep(Icons.add_shopping_cart, '۲. افزودن به سبد', 'می‌توانید چند کالا اضافه کنید'),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.amber),
          _buildGuideStep(Icons.credit_card, '۳. پرداخت نهایی', 'کل سبد را یکجا تسویه کنید'),
        ],
      ),
    );
  }

  Widget _buildGuideStep(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: Colors.amber.shade700),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}