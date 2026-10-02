import 'package:flutter/material.dart';

/// کیپد عددی لمسی با نقطه (برای وارد کردن IP و پورت؛ بدون کیبورد سیستم)
class IpPad extends StatelessWidget {
  static const Color _ink = Color(0xFF2B3A47);

  final ValueChanged<String> onKey; // رقم یا '.'
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final double keyHeight;

  const IpPad({
    super.key,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    this.keyHeight = 46,
  });

  Widget _key(String label, VoidCallback onTap, {IconData? icon, Color? bg, Color? fg}) {
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(children: row.map((d) => _key(d, () => onKey(d))).toList()),
            Row(
              children: [
                _key('.', () => onKey('.'), bg: Colors.blueGrey.shade50),
                _key('0', () => onKey('0')),
                _key('', onBackspace, icon: Icons.backspace_outlined, bg: Colors.blueGrey.shade50),
              ],
            ),
            Row(
              children: [
                _key('پاک کردن فیلد', onClear, bg: Colors.red.shade50, fg: Colors.red.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }
}