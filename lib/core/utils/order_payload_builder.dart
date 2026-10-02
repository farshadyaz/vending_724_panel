/// ساخت لیست سفارش برای برد الکترونیکی از روی سبد خرید:
///  - commands: کالاهای هر رک (شماره رک، آدرس فیزیکی، تعداد)
///  - addons:   جمع تعداد هر افزودنی در کل سبد (مثلاً اگر ۲ کالای سبد «آبجوش» داشته باشند، count = 2)
class OrderPayloadBuilder {
  /// جمع افزودنی‌های سبد؛ هر آیتم سبد = یک واحد کالا و افزودنی‌های رک خودش را (با تعدادشان) به جمع اضافه می‌کند.
  /// خروجی بر اساس شناسه افزودنی مرتب است: addon_id, cmd, name, icon_key, count
  static List<Map<String, dynamic>> aggregateAddons(List<Map<String, dynamic>> cart) {
    final Map<int, Map<String, dynamic>> totals = {};
    for (final item in cart) {
      final addons = item['addons'];
      if (addons is! List) continue;
      for (final a in addons) {
        if (a is! Map) continue;
        final int id = a['addon_id'] as int;
        final int qty = (a['qty'] as int?) ?? 1;
        final entry = totals.putIfAbsent(
          id,
          () => <String, dynamic>{
            'addon_id': id,
            'cmd': a['hardware_cmd']?.toString() ?? id.toString(),
            'name': a['name']?.toString() ?? '',
            'icon_key': a['icon_key']?.toString(),
            'count': 0,
          },
        );
        entry['count'] = (entry['count'] as int) + qty;
      }
    }
    final list = totals.values.toList();
    list.sort((a, b) => (a['addon_id'] as int).compareTo(b['addon_id'] as int));
    return list;
  }

  /// کالاهای سبد گروه‌بندی‌شده بر اساس رک: rack_number, physical_address, qty
  static List<Map<String, dynamic>> buildCommands(List<Map<String, dynamic>> cart) {
    final Map<int, Map<String, dynamic>> byRack = {};
    for (final item in cart) {
      final int rack = item['rack_number'] as int;
      final entry = byRack.putIfAbsent(
        rack,
        () => <String, dynamic>{
          'rack_number': rack,
          'physical_address': item['physical_address'],
          'qty': 0,
        },
      );
      entry['qty'] = (entry['qty'] as int) + 1;
    }
    return byRack.values.toList();
  }

  /// بسته کامل سفارش: order_id + commands + addons
  static Map<String, dynamic> build(String orderId, List<Map<String, dynamic>> cart) {
    return <String, dynamic>{
      'order_id': orderId,
      'commands': buildCommands(cart),
      'addons': aggregateAddons(cart),
    };
  }
}