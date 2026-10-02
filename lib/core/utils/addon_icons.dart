import 'package:flutter/material.dart';

/// آیکون‌های متریال قابل انتخاب برای افزودنی‌ها.
/// در دیتابیس فقط «کلید متنی» ذخیره می‌شود و با این جدول به آیکون تبدیل می‌شود.
class AddonIcons {
  static const String defaultKey = 'add_circle_outline';

  static const Map<String, IconData> icons = {
    'local_fire_department': Icons.local_fire_department,
    'whatshot': Icons.whatshot,
    'hot_tub': Icons.hot_tub,
    'thermostat': Icons.thermostat,
    'water_drop': Icons.water_drop,
    'opacity': Icons.opacity,
    'ac_unit': Icons.ac_unit,
    'coffee': Icons.coffee,
    'local_cafe': Icons.local_cafe,
    'emoji_food_beverage': Icons.emoji_food_beverage,
    'local_drink': Icons.local_drink,
    'sports_bar': Icons.sports_bar,
    'wine_bar': Icons.wine_bar,
    'liquor': Icons.liquor,
    'restaurant': Icons.restaurant,
    'restaurant_menu': Icons.restaurant_menu,
    'flatware': Icons.flatware,
    'fastfood': Icons.fastfood,
    'lunch_dining': Icons.lunch_dining,
    'dinner_dining': Icons.dinner_dining,
    'ramen_dining': Icons.ramen_dining,
    'soup_kitchen': Icons.soup_kitchen,
    'rice_bowl': Icons.rice_bowl,
    'set_meal': Icons.set_meal,
    'takeout_dining': Icons.takeout_dining,
    'local_pizza': Icons.local_pizza,
    'bakery_dining': Icons.bakery_dining,
    'breakfast_dining': Icons.breakfast_dining,
    'cookie': Icons.cookie,
    'cake': Icons.cake,
    'icecream': Icons.icecream,
    'egg': Icons.egg,
    'eco': Icons.eco,
    'grass': Icons.grass,
    'microwave': Icons.microwave,
    'blender': Icons.blender,
    'kitchen': Icons.kitchen,
    'bolt': Icons.bolt,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'inventory_2': Icons.inventory_2,
    'shopping_bag': Icons.shopping_bag,
    'cleaning_services': Icons.cleaning_services,
    'medication': Icons.medication,
    'science': Icons.science,
    'extension': Icons.extension,
    'add_circle_outline': Icons.add_circle_outline,
  };

  /// تبدیل کلید ذخیره‌شده به آیکون؛ کلید ناشناخته آیکون پیش‌فرض می‌دهد
  static IconData iconFor(String? key) => icons[key] ?? Icons.add_circle_outline;
}