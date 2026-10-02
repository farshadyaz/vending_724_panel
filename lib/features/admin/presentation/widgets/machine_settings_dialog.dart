import 'package:flutter/material.dart';
import '../../../../core/database/settings_repository.dart';
import '../../../../core/database/vending_repository.dart';
import '../../../../core/widgets/pin_pad.dart';
import 'addons_settings_tab.dart';

class MachineSettingsDialog extends StatefulWidget {
  const MachineSettingsDialog({super.key});

  @override
  State<MachineSettingsDialog> createState() => _MachineSettingsDialogState();
}

class _MachineSettingsDialogState extends State<MachineSettingsDialog> {
  static const Color _ink = Color(0xFF2B3A47);
  static const int _maxRacks = 99;
  static const int _maxColumns = 20;
  static const int _maxShelves = 20;

  final VendingRepository _repo = VendingRepository();
  final SettingsRepository _settings = SettingsRepository();

  // ساختار دستگاه
  List<int> _columns = [];
  bool _loading = true;
  bool _saving = false;

  // حالت پنل مشتری و ظرفیت سبد
  String _panelMode = SettingsRepository.panelModeKeypad;
  int _cartCapacity = SettingsRepository.defaultCartCapacity;

  // رمز اولیه
  String _storedPin = SettingsRepository.defaultAdminPin;
  int _pinStep = 0; // 0 = رمز فعلی، 1 = رمز جدید، 2 = تکرار رمز جدید
  String _pinValue = '';
  String _newPin = '';
  String? _pinMessage;
  bool _pinMessageIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final layout = await _repo.fetchLayout();
    final mode = await _settings.getPanelMode();
    final pin = await _settings.getAdminPin();
    final cap = await _settings.getCartCapacity();
    if (!mounted) return;
    setState(() {
      _columns = layout.map((e) => e['columns_count'] as int).toList();
      _panelMode = mode;
      _storedPin = pin;
      _cartCapacity = cap;
      _loading = false;
    });
  }

  int get _total => _columns.fold(0, (a, b) => a + b);

  void _toast(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green.shade700),
    );
  }

  // ---------------- ساختار دستگاه ----------------

  void _changeColumns(int index, int delta) {
    final next = _columns[index] + delta;
    if (next < 1 || next > _maxColumns) return;
    if (delta > 0 && _total + delta > _maxRacks) {
      _toast('مجموع رک‌ها نباید بیشتر از $_maxRacks باشد');
      return;
    }
    setState(() => _columns[index] = next);
  }

  void _addShelf() {
    if (_columns.length >= _maxShelves) {
      _toast('حداکثر $_maxShelves طبقه مجاز است');
      return;
    }
    if (_total + 10 > _maxRacks) {
      _toast('مجموع رک‌ها نباید بیشتر از $_maxRacks باشد');
      return;
    }
    setState(() => _columns.add(10));
  }

  void _removeLastShelf() {
    if (_columns.isEmpty) return;
    setState(() => _columns.removeLast());
  }

  Future<void> _saveStructure() async {
    setState(() => _saving = true);
    final res = await _repo.applyLayout(_columns);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.error != null) {
      _toast(res.error!);
      return;
    }
    _toast(
      res.moved > 0
          ? 'ساختار ذخیره شد؛ ${res.moved} رک همراه محصولشان به جای‌های جدید منتقل شد'
          : 'ساختار دستگاه ذخیره شد',
      error: false,
    );
  }

  // ---------------- حالت پنل مشتری ----------------

  Future<void> _selectPanelMode(String mode) async {
    if (mode == _panelMode) return;
    await _settings.setPanelMode(mode);
    if (!mounted) return;
    setState(() => _panelMode = mode);
    _toast(
      mode == SettingsRepository.panelModeLayout
          ? 'پنل مشتری روی «چیدمان رک‌ها» تنظیم شد؛ با بازگشت به صفحه مشتری اعمال می‌شود'
          : 'پنل مشتری روی «کیپد و کارت محصول» تنظیم شد؛ با بازگشت به صفحه مشتری اعمال می‌شود',
      error: false,
    );
  }

  // ---------------- ظرفیت سبد خرید ----------------

  Future<void> _changeCartCapacity(int delta) async {
    final int next = _cartCapacity + delta;
    if (next < SettingsRepository.minCartCapacity || next > SettingsRepository.maxCartCapacity) return;
    setState(() => _cartCapacity = next);
    await _settings.setCartCapacity(next);
  }

  // ---------------- رمز اولیه ----------------

  void _pinDigit(String d) {
    if (_pinValue.length >= 4) return;
    setState(() {
      _pinValue += d;
      _pinMessage = null;
    });
    if (_pinValue.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _pinSubmit);
    }
  }

  void _pinBackspace() {
    if (_pinValue.isEmpty) return;
    setState(() => _pinValue = _pinValue.substring(0, _pinValue.length - 1));
  }

  Future<void> _pinSubmit() async {
    if (!mounted || _pinValue.length != 4) return;
    final entered = _pinValue;

    if (_pinStep == 0) {
      if (entered == _storedPin) {
        setState(() {
          _pinStep = 1;
          _pinValue = '';
        });
      } else {
        setState(() {
          _pinValue = '';
          _pinMessage = 'رمز فعلی نادرست است';
          _pinMessageIsError = true;
        });
      }
    } else if (_pinStep == 1) {
      setState(() {
        _newPin = entered;
        _pinStep = 2;
        _pinValue = '';
      });
    } else {
      if (entered == _newPin) {
        await _settings.setAdminPin(entered);
        if (!mounted) return;
        setState(() {
          _storedPin = entered;
          _newPin = '';
          _pinStep = 0;
          _pinValue = '';
          _pinMessage = 'رمز اولیه با موفقیت تغییر کرد';
          _pinMessageIsError = false;
        });
      } else {
        setState(() {
          _newPin = '';
          _pinStep = 1;
          _pinValue = '';
          _pinMessage = 'تکرار رمز مطابقت نداشت؛ رمز جدید را دوباره وارد کنید';
          _pinMessageIsError = true;
        });
      }
    }
  }

  // ---------------- رابط ----------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : DefaultTabController(
                    length: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.settings_applications_outlined, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('تنظیمات دستگاه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                        const TabBar(
                          labelColor: _ink,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: _ink,
                          tabs: [
                            Tab(text: 'ساختار'),
                            Tab(text: 'پنل مشتری'),
                            Tab(text: 'افزودنی‌ها'),
                            Tab(text: 'رمز اولیه'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: TabBarView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _structureTab(),
                              _panelModeTab(),
                              const AddonsSettingsTab(),
                              _pinTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ---- تب ۱: ساختار ----

  Widget _structureTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تعداد طبقات: ${_columns.length}    |    مجموع رک‌ها: $_total',
          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'اگر با کم کردن رک‌ها، خانه‌ای حذف شود، محصول و موجودی آن به خانه‌های جدید (مثلاً طبقه تازه) منتقل می‌شود.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const Divider(),
        Expanded(
          child: _columns.isEmpty
              ? const Center(child: Text('هنوز طبقه‌ای تعریف نشده است', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _columns.length,
                  itemBuilder: (context, i) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Text('طبقه ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        const Text('تعداد رک'),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _changeColumns(i, -1),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('${_columns[i]}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _changeColumns(i, 1),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addShelf,
                icon: const Icon(Icons.add),
                label: const Text('افزودن طبقه'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _columns.isEmpty ? null : _removeLastShelf,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('حذف آخرین طبقه', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: (_saving || _columns.isEmpty) ? null : _saveStructure,
          style: ElevatedButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره ساختار دستگاه'),
        ),
      ],
    );
  }

  // ---- تب ۲: پنل مشتری (حالت پنل + ظرفیت سبد) ----

  Widget _panelModeTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'نوع پنل خرید مشتری را انتخاب کنید',
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _modeCard(
            mode: SettingsRepository.panelModeKeypad,
            title: 'کیپد و کارت محصول',
            description: 'مشتری شماره رک را با کیپد وارد می‌کند و کارت محصول کنار کیپد نمایش داده می‌شود.',
            preview: _previewKeypad(),
          ),
          const SizedBox(height: 10),
          _modeCard(
            mode: SettingsRepository.panelModeLayout,
            title: 'چیدمان رک‌ها',
            description:
                'چیدمان دستگاه (هر طبقه یک ردیف) نمایش داده می‌شود؛ با لمس هر رک، کارت محصول باز می‌شود و پس از افزودن به سبد به چیدمان برمی‌گردد.\nورود تکنسین: ۵ لمس سریع روی هدر و سپس رمز اولیه.',
            preview: _previewLayout(),
          ),
          const SizedBox(height: 16),
          _cartCapacityCard(),
          const SizedBox(height: 12),
          Text(
            'تغییرات با بازگشت از پنل مدیریت به صفحه مشتری اعمال می‌شود.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _cartCapacityCard() {
    final bool atMin = _cartCapacity <= SettingsRepository.minCartCapacity;
    final bool atMax = _cartCapacity >= SettingsRepository.maxCartCapacity;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.shopping_basket_outlined, color: Colors.blueGrey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ظرفیت سبد خرید', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
                const SizedBox(height: 2),
                Text(
                  'حداکثر تعداد کالا در هر خرید (${SettingsRepository.minCartCapacity} تا ${SettingsRepository.maxCartCapacity}) — برای هر دو نوع پنل',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: atMin ? null : () => _changeCartCapacity(-1),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$_cartCapacity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _ink),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: atMax ? null : () => _changeCartCapacity(1),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required String mode,
    required String title,
    required String description,
    required Widget preview,
  }) {
    final bool selected = _panelMode == mode;
    return InkWell(
      onTap: () => _selectPanelMode(mode),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.blueGrey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _ink : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 112, height: 82, child: preview),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? _ink : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBox(Color c, {double h = 12, double r = 3}) {
    return Container(
      height: h,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
    );
  }

  Widget _previewKeypad() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: List.generate(
                4,
                (r) => Row(
                  children: List.generate(
                    3,
                    (c) => Expanded(
                      child: _miniBox(r == 3 && c == 0 ? Colors.green.shade400 : (r == 3 && c == 2 ? Colors.red.shade300 : Colors.blueGrey.shade200), h: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
              child: Column(
                children: [
                  Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.orange.shade300, shape: BoxShape.circle)),
                  const SizedBox(height: 4),
                  _miniBox(Colors.blueGrey.shade200, h: 4),
                  _miniBox(Colors.green.shade300, h: 4),
                  const Spacer(),
                  _miniBox(Colors.blue.shade300, h: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewLayout() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (r) => Column(
            children: [
              Row(
                children: List.generate(
                  6,
                  (c) => Expanded(child: _miniBox((r + c) % 4 == 3 ? Colors.grey.shade300 : Colors.orange.shade200, h: 13)),
                ),
              ),
              Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: Colors.blueGrey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- تب ۴: رمز اولیه ----

  Widget _pinTab() {
    const titles = [
      'رمز اولیه فعلی را وارد کنید',
      'رمز اولیه جدید (۴ رقم) را وارد کنید',
      'رمز جدید را دوباره وارد کنید',
    ];
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'این رمز برای ورود تکنسین به پنل مدیریت (از صفحه مشتری) استفاده می‌شود.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Container(
                width: 28,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= _pinStep ? _ink : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(titles[_pinStep], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
          const SizedBox(height: 14),
          PinPad(
            value: _pinValue,
            error: _pinMessage != null && _pinMessageIsError,
            onDigit: _pinDigit,
            onBackspace: _pinBackspace,
            onClear: () => setState(() => _pinValue = ''),
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                _pinMessage ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _pinMessageIsError ? Colors.red.shade600 : Colors.green.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}