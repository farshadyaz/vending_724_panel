import 'package:flutter/material.dart';

class PersianKeyboardWidget extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onEnter;

  const PersianKeyboardWidget({
    super.key,
    required this.onKeyPressed,
    required this.onBackspace,
    required this.onSpace,
    required this.onEnter,
  });

  // انتقال ردیف اعداد به ایندکس ۰ (بالا) و چیدمان استاندارد کیبورد فیزیکی
  static const List<List<String>> _keyboardLayout = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج', 'چ'],
    ['ش', 'س', 'ی', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ک', 'گ'],
    ['ظ', 'ط', 'ز', 'ر', 'ذ', 'د', 'پ', 'و', 'ئ'],
  ];

  @override
  Widget build(BuildContext context) {
    // با استفاده از LTR، آیتم‌های آرایه دقیقا از چپ به راست چیده می‌شوند
    // در نتیجه 'ض' و '1' در سمت چپ و 'چ' و '0' در سمت راست قرار می‌گیرند
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._keyboardLayout.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // با استفاده از Expanded داخل تابع _buildKey، بیرون‌زدگی کاملاً رفع می‌شود
                    children: row.map((char) => _buildKey(char)).toList(),
                  ),
                )),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // در LTR دکمه‌ها از چپ به راست چیده می‌شوند: تایید، فاصله، حذف
                  _buildActionKey(Icons.keyboard_return, Colors.blue.shade600, onEnter, flex: 2),
                  _buildActionKey(Icons.space_bar, Colors.white, onSpace, flex: 6, isSpace: true),
                  _buildActionKey(Icons.backspace_outlined, Colors.red.shade400, onBackspace, flex: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String char) {
    // جایگزینی Container با عرض ثابت به Expanded برای ریسپانسیو شدن دکمه‌ها
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          elevation: 1,
          child: InkWell(
            onTap: () => onKeyPressed(char),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48, // فقط ارتفاع ثابت است
              alignment: Alignment.center,
              child: Text(
                char,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(IconData icon, Color bgColor, VoidCallback onTap, {required int flex, bool isSpace = false}) {
    // تخصیص وزن (flex) به جای عرض ثابت برای دکمه‌های کنترلی
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          elevation: 1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Icon(icon, color: isSpace ? Colors.black54 : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}