import 'package:flutter/material.dart';

class HeaderWidget extends StatelessWidget {
  final String title;
  final String supportNumber;

  const HeaderWidget({
    super.key,
    this.title = 'وندینگ ۷۲۴',
    this.supportNumber = 'پشتیبانی: ۰۲۱-۱۲۳۴۵۶',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(supportNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text(DateTime.now().toString().substring(0, 10), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}