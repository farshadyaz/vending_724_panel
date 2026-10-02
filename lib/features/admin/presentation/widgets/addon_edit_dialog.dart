import 'package:flutter/material.dart';
import '../../../../core/database/addon_repository.dart';
import '../../../../core/utils/addon_icons.dart';
import 'persian_keyboard_widget.dart';

/// افزودن / ویرایش یک افزودنی (نام، آیکون متریال، کد دستور برد)
/// با ذخیره موفق مقدار true برمی‌گرداند.
class AddonEditDialog extends StatefulWidget {
  final Map<String, dynamic>? addon; // null = افزودنی جدید

  const AddonEditDialog({super.key, this.addon});

  @override
  State<AddonEditDialog> createState() => _AddonEditDialogState();
}

class _AddonEditDialogState extends State<AddonEditDialog> {
  static const Color _ink = Color(0xFF2B3A47);

  final AddonRepository _repo = AddonRepository();

  String _name = '';
  String _code = '';
  String _iconKey = AddonIcons.defaultKey;
  int _activeField = 0; // 0 = نام، 1 = کد برد
  bool _saving = false;

  bool get _isEdit => widget.addon != null;

  @override
  void initState() {
    super.initState();
    final a = widget.addon;
    if (a != null) {
      _name = (a['name'] ?? '').toString();
      _code = (a['hardware_cmd'] ?? '').toString();
      final key = (a['icon_key'] ?? AddonIcons.defaultKey).toString();
      _iconKey = AddonIcons.icons.containsKey(key) ? key : AddonIcons.defaultKey;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  // ---------------- کیبورد ----------------

  void _onKeyPressed(String char) {
    setState(() {
      if (_activeField == 0) {
        if (_name.length < 24) _name += char;
      } else {
        // کد برد فقط عدد
        if (RegExp(r'^[0-9]$').hasMatch(char) && _code.length < 4) _code += char;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_activeField == 0) {
        if (_name.isNotEmpty) _name = _name.substring(0, _name.length - 1);
      } else {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      }
    });
  }

  void _onSpace() {
    if (_activeField == 0 && _name.isNotEmpty && !_name.endsWith(' ') && _name.length < 24) {
      setState(() => _name += ' ');
    }
  }

  void _onEnter() {
    if (_activeField == 0) {
      setState(() => _activeField = 1);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    if (_saving) return; // جلوگیری از ذخیره دوباره (مثلاً دو بار زدن Enter کیبورد)
    final name = _name.trim();
    if (name.isEmpty) {
      _toast('نام افزودنی را وارد کنید');
      setState(() => _activeField = 0);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repo.updateAddon(
          id: widget.addon!['id'] as int,
          name: name,
          iconKey: _iconKey,
          cmd: _code,
        );
      } else {
        await _repo.addAddon(name: name, iconKey: _iconKey, cmd: _code);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('خطا در ذخیره افزودنی: $e');
      }
    }
  }

  // ---------------- رابط ----------------

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.of(context).size.height * 0.94;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760, maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(12)),
                      child: Icon(AddonIcons.iconFor(_iconKey), color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEdit ? 'ویرایش افزودنی' : 'افزودنی جدید',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _field(
                                label: 'نام افزودنی',
                                text: _name,
                                hint: 'مثال: آبجوش',
                                active: _activeField == 0,
                                onTap: () => setState(() => _activeField = 0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _field(
                                label: 'کد دستور برد (عدد)',
                                text: _code,
                                hint: 'خالی = خودکار',
                                active: _activeField == 1,
                                onTap: () => setState(() => _activeField = 1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('آیکون', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AddonIcons.icons.entries.map((e) {
                            final bool selected = e.key == _iconKey;
                            return InkWell(
                              onTap: () => setState(() => _iconKey = e.key),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: selected ? _ink : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: selected ? _ink : Colors.grey.shade300),
                                ),
                                child: Icon(e.value, color: selected ? Colors.white : Colors.blueGrey.shade700),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PersianKeyboardWidget(
                  onKeyPressed: _onKeyPressed,
                  onBackspace: _onBackspace,
                  onSpace: _onSpace,
                  onEnter: _onEnter,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('انصراف', style: TextStyle(color: _ink)),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره'),
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

  // فیلد کاستوم که کیبورد سیستم را باز نمی‌کند
  Widget _field({
    required String label,
    required String text,
    required String hint,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: active ? Colors.blueGrey.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? _ink : Colors.grey.shade300, width: active ? 2 : 1),
            ),
            child: Text(
              text.isEmpty ? hint : (active ? '$text|' : text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                color: text.isEmpty ? Colors.grey.shade400 : Colors.black87,
                fontWeight: text.isEmpty ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}