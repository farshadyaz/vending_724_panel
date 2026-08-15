import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/database/vending_repository.dart';
import 'persian_keyboard_widget.dart';

class ProductListDialog extends StatefulWidget {
  const ProductListDialog({super.key});

  @override
  State<ProductListDialog> createState() => _ProductListDialogState();
}

class _ProductListDialogState extends State<ProductListDialog> {
  final VendingRepository _repo = VendingRepository();
  List<Map<String, dynamic>> _products = [];
  Map<int, bool> _lockedProducts = {}; 

  int? _editingProductId;
  String _editName = '';
  String _editPrice = '';
  String? _editImagePath;
  bool _hasNewImage = false;
  int _activeField = 1; // 1 = Name, 2 = Price

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _repo.fetchActiveProducts();
    final Map<int, bool> lockedMap = {};
    for (var p in products) {
      lockedMap[p['id']] = await _repo.isProductInActiveRack(p['id']);
    }
    if (mounted) {
      setState(() {
        _products = products;
        _lockedProducts = lockedMap;
      });
    }
  }

  Future<void> _deleteProduct(int id) async {
    await _repo.softDeleteProduct(id);
    _loadProducts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('محصول از لیست حذف شد.', style: TextStyle(fontFamily: 'Vazir'))),
      );
    }
  }

  void _startEditing(Map<String, dynamic> product) {
    setState(() {
      _editingProductId = product['id'];
      _editName = product['name'];
      _editPrice = product['base_price'].toString();
      _editImagePath = product['image_path'];
      _hasNewImage = false;
      _activeField = 1;
    });
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() {
        _editImagePath = pickedFile.path;
        _hasNewImage = true;
      });
    }
  }

  Future<void> _saveEdit() async {
    if (_editName.isEmpty || _editPrice.isEmpty) return;

    await _repo.updateProduct(
      _editingProductId!,
      _editName,
      int.parse(_editPrice),
      _hasNewImage ? _editImagePath : null, 
    );

    setState(() => _editingProductId = null);
    _loadProducts();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییرات با موفقیت ذخیره شد.', style: TextStyle(fontFamily: 'Vazir')), backgroundColor: Colors.green),
      );
    }
  }

  void _onKeyPressed(String char) {
    setState(() {
      if (_activeField == 1) {
        if (_editName.length < 50) _editName += char;
      } else if (_activeField == 2) {
        if (RegExp(r'^[0-9]$').hasMatch(char) && _editPrice.length < 10) _editPrice += char;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_activeField == 1 && _editName.isNotEmpty) {
        _editName = _editName.substring(0, _editName.length - 1);
      } else if (_activeField == 2 && _editPrice.isNotEmpty) {
        _editPrice = _editPrice.substring(0, _editPrice.length - 1);
      }
    });
  }

  void _onSpace() {
    if (_activeField == 1) setState(() => _editName += ' ');
  }

  void _onEnter() {
    if (_activeField == 1) {
      setState(() => _activeField = 2);
    } else {
      _saveEdit();
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('لیست و ویرایش محصولات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              Expanded(
                child: _products.isEmpty
                    ? const Center(child: Text('محصولی یافت نشد.', style: TextStyle(color: Colors.grey, fontSize: 18)))
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final isEditing = _editingProductId == product['id'];
                          
                          if (isEditing) return _buildEditAccordion(product);
                          return _buildNormalRow(product);
                        },
                      ),
              ),

              if (_editingProductId != null) ...[
                const SizedBox(height: 16),
                PersianKeyboardWidget(
                  onKeyPressed: _onKeyPressed,
                  onBackspace: _onBackspace,
                  onSpace: _onSpace,
                  onEnter: _onEnter,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalRow(Map<String, dynamic> product) {
    final bool isLocked = _lockedProducts[product['id']] ?? false;
    
    return Card(
      elevation: 0,
      color: Colors.white,
      // رفع خطای border: جایگزینی با side
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(product['image_path']), 
            width: 56, 
            height: 56, 
            fit: BoxFit.cover,
            // رفع اخطار underscores
            errorBuilder: (context, error, stackTrace) => Container(
              width: 56, 
              height: 56, 
              color: Colors.grey.shade200, 
              child: const Icon(Icons.image, color: Colors.grey),
            ),
          ),
        ),
        title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(int.parse(product['base_price'].toString()).toRial, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'ویرایش سریع',
              icon: const Icon(Icons.edit_note, color: Colors.blue, size: 28),
              onPressed: () => _startEditing(product),
            ),
            IconButton(
              tooltip: isLocked ? 'محصول در رک فعال موجود است' : 'حذف',
              icon: Icon(Icons.delete_outline, color: isLocked ? Colors.grey.shade300 : Colors.red, size: 28),
              onPressed: isLocked ? null : () => _deleteProduct(product['id']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditAccordion(Map<String, dynamic> product) {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      // رفع خطای border: جایگزینی با side
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.blue.shade200),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 90,
                  height: 90,
                  color: Colors.white,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_editImagePath != null)
                        Image.file(
                          File(_editImagePath!), 
                          fit: BoxFit.cover, 
                          // رفع اخطار underscores
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                        ),
                      Container(color: Colors.black.withValues(alpha: 0.3)),
                      const Center(child: Icon(Icons.camera_alt, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildCustomTextField(
                    text: _editName,
                    isActive: _activeField == 1,
                    onTap: () => setState(() => _activeField = 1),
                    hint: 'نام محصول',
                  ),
                  const SizedBox(height: 8),
                  _buildCustomTextField(
                    text: _editPrice.isEmpty ? '' : int.parse(_editPrice).toRial,
                    isActive: _activeField == 2,
                    onTap: () => setState(() => _activeField = 2),
                    hint: 'قیمت پایه',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                SizedBox(
                  width: 110,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _saveEdit,
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: const Text('ذخیره', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 110,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _editingProductId = null),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('انصراف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({required String text, required bool isActive, required VoidCallback onTap, required String hint}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Colors.blue.shade600 : Colors.grey.shade300, width: isActive ? 2 : 1),
        ),
        child: Text(
          text.isEmpty ? hint : (isActive ? '$text|' : text), 
          style: TextStyle(
            fontSize: 16,
            color: text.isEmpty ? Colors.grey.shade400 : Colors.black87,
            fontWeight: text.isEmpty ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ),
    );
  }
}