import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AdSliderWidget extends StatefulWidget {
  const AdSliderWidget({super.key});

  @override
  State<AdSliderWidget> createState() => _AdSliderWidgetState();
}

class _AdSliderWidgetState extends State<AdSliderWidget> {
  // این لیست در آینده مستقیماً از کوئری دیتابیس (پس از تنظیمات ادمین) پر خواهد شد
  final List<Map<String, dynamic>> _adminConfiguredAds = [
    {
      'id': 1,
      'is_active': true,
      'display_weight': 60, // 60% شانس نمایش
      'text': 'تبلیغ ویژه محصولات خنک\n(نمایش زیاد - ۶۰٪)',
      'color': Colors.blue.shade100,
    },
    {
      'id': 2,
      'is_active': true,
      'display_weight': 30, // 30% شانس نمایش
      'text': 'اسپانسر: قهوه لمیز\n(نمایش متوسط - ۳۰٪)',
      'color': Colors.brown.shade100,
    },
    {
      'id': 3,
      'is_active': false, // ادمین این تبلیغ را غیرفعال کرده است
      'display_weight': 50,
      'text': 'تبلیغ منقضی شده\n(نباید نمایش داده شود)',
      'color': Colors.red.shade100,
    },
    {
      'id': 4,
      'is_active': true,
      'display_weight': 10, // 10% شانس نمایش
      'text': 'فقط امروز: تخفیف اسنک\n(نمایش کم - ۱۰٪)',
      'color': Colors.green.shade100,
    }
  ];

  Map<String, dynamic>? _currentAd;
  Timer? _rotationTimer;
  final Random _random = Random();
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _pickNextAd();
    // تایمر چرخش: هر ۵ ثانیه یک تبلیغ جدید بر اساس وزن انتخاب می‌شود
    _rotationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _animateAndPickNextAd();
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _animateAndPickNextAd() {
    setState(() => _isVisible = false);
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _pickNextAd();
        setState(() => _isVisible = true);
      }
    });
  }

  void _pickNextAd() {
    // ۱. فیلتر کردن فقط تبلیغات فعال
    final activeAds = _adminConfiguredAds.where((ad) => ad['is_active'] == true).toList();

    if (activeAds.isEmpty) {
      _currentAd = null;
      return;
    }

    // ۲. محاسبه مجموع وزن‌ها
    int totalWeight = activeAds.fold(0, (sum, ad) => sum + (ad['display_weight'] as int));

    // ۳. انتخاب تصادفی مبتنی بر وزن (Weighted Random)
    int randomValue = _random.nextInt(totalWeight);
    int cumulativeWeight = 0;

    for (var ad in activeAds) {
      cumulativeWeight += ad['display_weight'] as int;
      if (randomValue < cumulativeWeight) {
        setState(() {
          _currentAd = ad;
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAd == null) {
      return _buildPlaceholder(); // اگر هیچ تبلیغی فعال نبود
    }

    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        // مارجین افقی حذف شد تا تمام‌عرض شود. فقط کمی مارجین عمودی برای فاصله با بالا و پایین نگه می‌داریم
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: _currentAd!['color'],
          // borderRadius حذف شد تا گوشه‌ها مستطیل و صنعتی باشند
          border: const Border(
            top: BorderSide(color: Colors.black12, width: 1.5),
            bottom: BorderSide(color: Colors.black12, width: 1.5),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _currentAd!['text'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      // مارجین افقی حذف شد
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        // borderRadius حذف شد
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1.5),
          bottom: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'جای تبلیغات شما',
            style: TextStyle(
              fontSize: 22,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}