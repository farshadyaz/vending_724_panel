import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/extensions.dart'; 
import 'persian_keyboard_widget.dart'; 
import '../../../../core/database/vending_repository.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  String _productName = '';
  String _productPrice = '';
  String? _imagePath;
  int _activeField = 1; // 1 = Name, 2 = Price

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60, // فشرده‌سازی در لحظه
      maxWidth: 800, // محدود کردن سایز تصویر
    );

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  void _onKeyPressed(String char) {
    setState(() {
      if (_activeField == 1) {
        if (_productName.length < 50) _productName += char;
      } else if (_activeField == 2) {
        // در فیلد قیمت فقط اعداد مجاز هستند
        if (RegExp(r'^[0-9]$').hasMatch(char) && _productPrice.length < 10) {
          _productPrice += char;
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_activeField == 1 && _productName.isNotEmpty) {
        _productName = _productName.substring(0, _productName.length - 1);
      } else if (_activeField == 2 && _productPrice.isNotEmpty) {
        _productPrice = _productPrice.substring(0, _productPrice.length - 1);
      }
    });
  }

  void _onSpace() {
    if (_activeField == 1) {
      setState(() => _productName += ' ');
    }
  }

  void _onEnter() {
    if (_activeField == 1) {
      setState(() => _activeField = 2);
    } else {
      _saveProduct();
    }
  }

  Future<void> _saveProduct() async {
    if (_productName.isEmpty || _productPrice.isEmpty || _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً نام، قیمت و تصویر محصول را تکمیل کنید.', style: TextStyle(fontFamily: 'Vazir'))),
      );
      return;
    }
    
    try {
      final int price = int.parse(_productPrice);
      final repo = VendingRepository();
      
      // اجرای متد کپی تصویر و درج در دیتابیس
      await repo.addProduct(_productName, _imagePath!, price);

      if (mounted) {
        // نمایش پیام موفقیت
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('محصول «$_productName» با موفقیت افزوده شد.', style: const TextStyle(fontFamily: 'Vazir', fontWeight: FontWeight.bold)), 
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // پاکسازی و ریست کردن فرم جهت درج محصول بعدی (پاپ‌آپ بسته نمی‌شود)
        setState(() {
          _productName = '';
          _productPrice = '';
          _imagePath = null;
          _activeField = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره محصول: $e', style: const TextStyle(fontFamily: 'Vazir')), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 850,
          height: 720,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // هدر پاپ‌آپ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('افزودن محصول جدید', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بخش فرم ورود اطلاعات
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('نام محصول:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildCustomTextField(
                            text: _productName,
                            isActive: _activeField == 1,
                            onTap: () => setState(() => _activeField = 1),
                            hint: 'مثال: آب معدنی دماوند',
                          ),
                          const SizedBox(height: 24),
                          const Text('قیمت پایه (ریال):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildCustomTextField(
                            text: _productPrice.isEmpty ? '' : int.parse(_productPrice).toRial, 
                            isActive: _activeField == 2,
                            onTap: () => setState(() => _activeField = 2),
                            hint: 'مثال: 50,000',
                          ),
                          const SizedBox(height: 32),
                          // دکمه صریح برای ثبت فرم در UI
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _saveProduct,
                              icon: const Icon(Icons.save_outlined, color: Colors.white),
                              label: const Text('ثبت و افزودن محصول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // بخش آپلود تصویر
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تصویر محصول:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blueGrey.shade200, width: 2),
                                image: _imagePath != null
                                    ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.contain)
                                    : null,
                              ),
                              child: _imagePath == null
                                  ? const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo, size: 48, color: Colors.blueGrey),
                                        SizedBox(height: 8),
                                        Text('انتخاب از گالری/سیستم', style: TextStyle(color: Colors.blueGrey)),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // کیبورد اختصاصی
              PersianKeyboardWidget(
                onKeyPressed: _onKeyPressed,
                onBackspace: _onBackspace,
                onSpace: _onSpace,
                onEnter: _onEnter,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // فیلد کاستوم که کیبورد ویندوز/اندروید را باز نمی‌کند
  Widget _buildCustomTextField({required String text, required bool isActive, required VoidCallback onTap, required String hint}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? Colors.blue.shade600 : Colors.grey.shade300, width: isActive ? 2 : 1),
          boxShadow: isActive ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 8)] : [],
        ),
        child: Text(
          text.isEmpty ? hint : (isActive ? '$text|' : text), 
          style: TextStyle(
            fontSize: 18,
            color: text.isEmpty ? Colors.grey.shade400 : Colors.black87,
            fontWeight: text.isEmpty ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ),
    );
  }
}