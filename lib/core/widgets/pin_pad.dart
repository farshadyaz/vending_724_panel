import 'package:flutter/material.dart';

/// نمایش کادرهای رمز + کیپد عددی لمسی (بدون کیبورد سیستم)
class PinPad extends StatelessWidget {
  static const Color _ink = Color(0xFF2B3A47);

  final String value;
  final int length;
  final bool obscure;
  final bool error;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onClear;
  final double keyHeight;

  const PinPad({
    super.key,
    required this.value,
    required this.onDigit,
    required this.onBackspace,
    this.onClear,
    this.length = 4,
    this.obscure = true,
    this.error = false,
    this.keyHeight = 50,
  });

  Widget _key(String label, VoidCallback? onTap, {IconData? icon, Color? bg, Color? fg}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: bg ?? Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: keyHeight,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 22, color: fg ?? _ink)
                    : Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: fg ?? _ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(length, (i) {
              final bool filled = value.length > i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 46,
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? Colors.blueGrey.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: error ? Colors.red.shade500 : (filled ? _ink : Colors.grey.shade300),
                    width: filled || error ? 2 : 1,
                  ),
                ),
                child: Text(
                  filled ? (obscure ? '●' : value[i]) : '',
                  style: TextStyle(fontSize: obscure ? 16 : 22, fontWeight: FontWeight.bold, color: _ink),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 290,
            child: Column(
              children: [
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(children: row.map((d) => _key(d, () => onDigit(d))).toList()),
                Row(
                  children: [
                    _key('پاک', onClear, bg: Colors.red.shade50, fg: Colors.red.shade700),
                    _key('0', () => onDigit('0')),
                    _key('', onBackspace, icon: Icons.backspace_outlined, bg: Colors.blueGrey.shade50),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
