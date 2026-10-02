import 'dart:io';
import 'package:flutter/material.dart';

/// تصویر کالا؛ اگر عکس نباشد یک بسته رنگی با حرف اول نام کالا نشان می‌دهد.
/// عکس با BoxFit.cover کل فضا را پر می‌کند (لبه‌های اضافی عکس بریده می‌شود).
class ProductThumb extends StatelessWidget {
  final String name;
  final String? imagePath;
  final double size;
  final BoxFit fit;
  final double? radius; // پیش‌فرض: ۱۰٪ اندازه

  const ProductThumb({
    super.key,
    required this.name,
    required this.size,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.radius,
  });

  static Color _hashColor(String s) {
    final colors = <Color>[
      Colors.red.shade400,
      Colors.blue.shade500,
      Colors.teal.shade500,
      Colors.orange.shade600,
      Colors.purple.shade400,
      Colors.green.shade600,
      Colors.indigo.shade400,
      Colors.pink.shade400,
    ];
    int h = 0;
    for (final c in s.runes) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return colors[h % colors.length];
  }

  Widget _pack() {
    final base = _hashColor(name);
    final letter = name.isEmpty ? '؟' : String.fromCharCode(name.runes.first);
    return Center(
      child: Container(
        width: size * 0.62,
        height: size * 0.82,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base.withValues(alpha: 0.75), base],
          ),
          borderRadius: BorderRadius.circular(size * 0.12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.32),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? size * 0.1),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _pack(),
        ),
      );
    }
    return _pack();
  }
}