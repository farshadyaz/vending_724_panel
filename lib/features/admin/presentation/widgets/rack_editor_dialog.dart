import 'package:flutter/material.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/addon_icons.dart';
import '../../../../core/database/addon_repository.dart';
import '../../../../core/database/settings_repository.dart';
import '../../../../core/database/vending_repository.dart';
import 'product_thumb.dart';

class RackEditorDialog extends StatefulWidget {
  final int rackNumber;
  final int physicalAddress;
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> products;

  const RackEditorDialog({
    super.key,
    required this.rackNumber,
    required this.physicalAddress,
    required this.existing,
    required this.products,
  });

  @override
  State<RackEditorDialog> createState() => _RackEditorDialogState();
}

class _RackEditorDialogState extends State<RackEditorDialog> {
  static const Color _ink = Color(0xFF2B3A47);
  static const int _maxAddonQty = 9;

  final VendingRepository _repo = VendingRepository();
  final AddonRepository _addonRepo = AddonRepository();
  final SettingsRepository _settings = SettingsRepository();

  int? _productId;
  String _price = '0';
  String _stock = '0';
  bool _active = true;
  int _field = 0; // 0 = قیمت، 1 = موجودی
  bool _fresh = true; // اولین رقم بعد از انتخاب کادر، مقدار قبلی را جایگزین می‌کند

  // افزودنی‌های این رک (افزودنی‌ها به رک نسبت داده می‌شوند، نه به محصول)
  List<Map<String, dynamic>> _allAddons = [];
  final Map<int, int> _addonQty = {}; // addon_id ← تعداد به‌ازای هر کالا
  int _maxAddons = SettingsRepository.defaultMaxAddonsPerRack;
  String? _addonHint;
  bool _addonsLoaded = false; // قبل از بارگذاری افزودنی‌ها، ذخیره نباید افزودنی‌های قبلی را پاک کند

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _productId = r['product_id'] as int;
      _price = (r['current_price'] as int).toString();
      _stock = (r['stock'] as int).toString();
      _active = (r['status'] as int) == 1;
    }
    // اگر محصول رک بعداً حذف نرم شده باشد، از لیست انتخاب خارج می‌شود
    if (!widget.products.any((p) => p['id'] == _productId)) _productId = null;
    _loadAddons();
  }

  Future<void> _loadAddons() async {
    final all = await _addonRepo.fetchAddons();
    final max = await _settings.getMaxAddonsPerRack();
    final List<Map<String, dynamic>> current =
        widget.existing == null ? <Map<String, dynamic>>[] : await _addonRepo.fetchRackAddons(widget.rackNumber);
    if (!mounted) return;
    setState(() {
      _addonsLoaded = true;
      _allAddons = all;
      _maxAddons = max;
      _addonQty.clear();
      for (final a in current) {
        _addonQty[a['addon_id'] as int] = (a['qty'] as int?) ?? 1;
      }
    });
  }

  Map<String, dynamic>? get _product {
    for (final p in widget.products) {
      if (p['id'] == _productId) return p;
    }
    return null;
  }

  int get _priceInt => int.tryParse(_price) ?? 0;
  int get _stockInt => int.tryParse(_stock) ?? 0;

  String _fmt(String digits) {
    return (int.tryParse(digits) ?? 0).toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  // --- کیپد ---

  void _press(String d) {
    setState(() {
      if (_field == 0) {
        if (_fresh) _price = '0';
        if (_price.length < 9) _price = (_price == '0') ? d : _price + d;
      } else {
        if (_fresh) _stock = '0';
        if (_stock.length < 3) _stock = (_stock == '0') ? d : _stock + d;
      }
      _fresh = false;
    });
  }

  void _backspace() {
    setState(() {
      if (_field == 0) {
        _price = _price.length <= 1 ? '0' : _price.substring(0, _price.length - 1);
      } else {
        _stock = _stock.length <= 1 ? '0' : _stock.substring(0, _stock.length - 1);
      }
      _fresh = false;
    });
  }

  void _clearField() {
    setState(() {
      if (_field == 0) {
        _price = '0';
      } else {
        _stock = '0';
      }
      _fresh = false;
    });
  }

  // --- افزودنی‌ها ---

  void _toggleAddon(int id) {
    setState(() {
      if (_addonQty.containsKey(id)) {
        _addonQty.remove(id);
        _addonHint = null;
      } else if (_addonQty.length >= _maxAddons) {
        _addonHint = 'حداکثر $_maxAddons افزودنی برای هر رک مجاز است (از تنظیمات دستگاه قابل تغییر)';
      } else {
        _addonQty[id] = 1;
        _addonHint = null;
      }
    });
  }

  void _changeAddonQty(int id, int delta) {
    final int current = _addonQty[id] ?? 1;
    final int next = current + delta;
    if (next < 1 || next > _maxAddonQty) return;
    setState(() => _addonQty[id] = next);
  }

  // --- انتخاب محصول ---

  Future<void> _pickProduct() async {
    final id = await showDialog<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('انتخاب محصول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _ink)),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: widget.products.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'ابتدا از بخش «افزودن محصول» یک محصول تعریف کنید.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: widget.products.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final p = widget.products[i];
                            final selected = p['id'] == _productId;
                            return ListTile(
                              selected: selected,
                              selectedTileColor: Colors.blueGrey.shade50,
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ProductThumb(name: p['name'] as String, imagePath: p['image_path'] as String?, size: 48),
                              ),
                              title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text((p['base_price'] as int).toRial, style: TextStyle(color: Colors.grey.shade600)),
                              trailing: selected ? const Icon(Icons.check_circle, color: _ink) : null,
                              onTap: () => Navigator.pop(ctx, p['id'] as int),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (id != null && mounted) {
      final p = widget.products.firstWhere((p) => p['id'] == id);
      setState(() {
        _productId = id;
        _price = (p['base_price'] as int).toString();
        _field = 0;
        _fresh = true;
      });
    }
  }

  // --- ذخیره / حذف ---

  Future<void> _save() async {
    if (_productId == null) return;
    await _repo.saveRack(
      rackNumber: widget.rackNumber,
      physicalAddress: widget.physicalAddress,
      productId: _productId!,
      price: _priceInt,
      stock: _stockInt,
      active: _active,
    );
    // افزودنی‌های این رک (حتی وقتی بخش افزودنی مخفی است، مقدار قبلی دست‌نخورده ذخیره می‌شود)
    if (_addonsLoaded) {
      await _addonRepo.setRackAddons(widget.rackNumber, Map<int, int>.from(_addonQty));
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _clear() async {
    await _repo.clearRack(widget.rackNumber);
    if (mounted) Navigator.pop(context, true);
  }

  // --- اجزای رابط ---

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(12)),
          child: Text('${widget.rackNumber}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تنظیمات رک', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _ink)),
              Text('آدرس فیزیکی ${widget.physicalAddress}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
      ],
    );
  }

  Widget _productCard() {
    final p = _product;
    return InkWell(
      onTap: _pickProduct,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(10)),
              child: p == null
                  ? Icon(Icons.add_photo_alternate_outlined, color: Colors.blueGrey.shade300)
                  : ProductThumb(name: p['name'] as String, imagePath: p['image_path'] as String?, size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('محصول', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(
                    p == null ? 'انتخاب محصول...' : p['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: p == null ? Colors.grey.shade500 : _ink,
                    ),
                  ),
                  if (p != null)
                    Text('قیمت پایه: ${(p['base_price'] as int).toRial}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.unfold_more, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _fieldBox({required int index, required String label, required String value, String? suffix}) {
    final selected = _field == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _field = index;
          _fresh = true;
        }),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.blueGrey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _ink : Colors.grey.shade300, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _ink)),
                    ),
                  ),
                  if (suffix != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(suffix, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بخش افزودنی‌های رک: انتخاب چند افزودنی (تا سقف تنظیم‌شده) + تعداد به‌ازای هر کالا
  Widget _addonsSection() {
    if (_maxAddons == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('افزودنی‌های این رک', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink)),
              const Spacer(),
              Text('${_addonQty.length} از $_maxAddons', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 8),
          if (_allAddons.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'افزودنی‌ای تعریف نشده است. از «تنظیمات دستگاه ← افزودنی‌ها» اضافه کنید.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allAddons.map(_addonChip).toList(),
            ),
          if (_addonHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_addonHint!, style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _addonChip(Map<String, dynamic> a) {
    final int id = a['id'] as int;
    final bool selected = _addonQty.containsKey(id);
    final int qty = _addonQty[id] ?? 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: selected ? _ink : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _ink : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _toggleAddon(id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AddonIcons.iconFor(a['icon_key'] as String?),
                    size: 20,
                    color: selected ? Colors.white : Colors.blueGrey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (a['name'] ?? '').toString(),
                    style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : _ink),
                  ),
                ],
              ),
            ),
          ),
          if (selected) ...[
            Container(width: 1, height: 22, color: Colors.white24),
            _qtyButton(Icons.remove, () => _changeAddonQty(id, -1)),
            SizedBox(
              width: 22,
              child: Text(
                '$qty',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            _qtyButton(Icons.add, () => _changeAddonQty(id, 1)),
          ],
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _statusToggle() {
    Widget seg(bool value, String label, IconData icon, Color color) {
      final selected = _active == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _active = value),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          seg(true, 'فعال', Icons.check_circle_outline, Colors.green.shade600),
          seg(false, 'غیرفعال (قرنطینه)', Icons.block, Colors.red.shade600),
        ],
      ),
    );
  }

  Widget _keypad() {
    Widget key(String label, VoidCallback onTap, {IconData? icon, Color? bg, Color? fg}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: Material(
            color: bg ?? Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: 20, color: fg ?? _ink)
                      : Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: fg ?? _ink)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(children: row.map((d) => key(d, () => _press(d))).toList()),
          Row(
            children: [
              key('پاک', _clearField, bg: Colors.red.shade50, fg: Colors.red.shade700),
              key('0', () => _press('0')),
              key('', _backspace, icon: Icons.backspace_outlined, bg: Colors.blueGrey.shade50),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final basePrice = p == null ? null : p['base_price'] as int;
    final canSave = _productId != null && _priceInt > 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 14),
                _productCard(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _fieldBox(index: 0, label: 'قیمت فروش', value: _fmt(_price), suffix: 'ریال'),
                    const SizedBox(width: 10),
                    _fieldBox(index: 1, label: 'موجودی', value: _fmt(_stock), suffix: 'عدد'),
                  ],
                ),
                if (basePrice != null && basePrice != _priceInt)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _price = basePrice.toString();
                        _field = 0;
                        _fresh = true;
                      }),
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text('برگشت به قیمت پایه (${_fmt(basePrice.toString())})', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                _addonsSection(),
                const SizedBox(height: 10),
                _statusToggle(),
                const SizedBox(height: 10),
                _keypad(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (widget.existing != null)
                      TextButton(
                        onPressed: _clear,
                        child: Text('خالی کردن رک', style: TextStyle(color: Colors.red.shade700)),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('انصراف', style: TextStyle(color: _ink)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ذخیره', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}