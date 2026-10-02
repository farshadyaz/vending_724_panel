import 'package:flutter/material.dart';
import '../../../../core/database/addon_repository.dart';
import '../../../../core/database/settings_repository.dart';
import '../../../../core/utils/addon_icons.dart';
import 'addon_edit_dialog.dart';

/// تب «افزودنی‌ها» در تنظیمات دستگاه:
/// ۱) حداکثر تعداد افزودنی هر رک  ۲) تعریف / ویرایش / حذف افزودنی‌ها (با آیکون متریال)
class AddonsSettingsTab extends StatefulWidget {
  const AddonsSettingsTab({super.key});

  @override
  State<AddonsSettingsTab> createState() => _AddonsSettingsTabState();
}

class _AddonsSettingsTabState extends State<AddonsSettingsTab> {
  static const Color _ink = Color(0xFF2B3A47);

  final AddonRepository _repo = AddonRepository();
  final SettingsRepository _settings = SettingsRepository();

  List<Map<String, dynamic>> _addons = [];
  Map<int, int> _usage = {};
  int _maxPerRack = SettingsRepository.defaultMaxAddonsPerRack;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final addons = await _repo.fetchAddons();
    final usage = await _repo.fetchAddonUsage();
    final max = await _settings.getMaxAddonsPerRack();
    if (!mounted) return;
    setState(() {
      _addons = addons;
      _usage = usage;
      _maxPerRack = max;
      _loading = false;
    });
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green.shade700),
    );
  }

  Future<void> _changeMax(int delta) async {
    final int next = _maxPerRack + delta;
    if (next < SettingsRepository.minAddonsPerRackLimit || next > SettingsRepository.maxAddonsPerRackLimit) return;
    setState(() => _maxPerRack = next);
    await _settings.setMaxAddonsPerRack(next);
  }

  Future<void> _openEditor([Map<String, dynamic>? addon]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddonEditDialog(addon: addon),
    );
    if (saved == true) {
      await _load();
      if (mounted) _toast(addon == null ? 'افزودنی جدید اضافه شد' : 'افزودنی ویرایش شد');
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> addon) async {
    final int id = addon['id'] as int;
    final int used = _usage[id] ?? 0;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('حذف افزودنی', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: Text(
            used > 0
                ? 'افزودنی «${addon['name']}» در $used رک استفاده شده است. با حذف آن، از همه این رک‌ها برداشته می‌شود. ادامه می‌دهید؟'
                : 'افزودنی «${addon['name']}» حذف شود؟',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('حذف', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _repo.deleteAddon(id);
      await _load();
      if (mounted) _toast('افزودنی حذف شد');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _maxPerRackCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'افزودنی‌های تعریف‌شده (${_addons.length})',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _addons.isEmpty
              ? Center(
                  child: Text(
                    'هنوز افزودنی‌ای تعریف نشده است',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.builder(
                  itemCount: _addons.length,
                  itemBuilder: (context, i) => _addonRow(_addons[i]),
                ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _openEditor(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add),
          label: const Text('افزودن افزودنی جدید'),
        ),
      ],
    );
  }

  Widget _maxPerRackCard() {
    final bool atMin = _maxPerRack <= SettingsRepository.minAddonsPerRackLimit;
    final bool atMax = _maxPerRack >= SettingsRepository.maxAddonsPerRackLimit;
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
            child: Icon(Icons.extension_outlined, color: Colors.blueGrey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('حداکثر افزودنی برای هر رک', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
                const SizedBox(height: 2),
                Text(
                  _maxPerRack == 0
                      ? 'صفر: قابلیت افزودنی برای رک‌ها غیرفعال است'
                      : 'هر رک نهایتاً $_maxPerRack نوع افزودنی می‌تواند داشته باشد',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: atMin ? null : () => _changeMax(-1),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$_maxPerRack',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _ink),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: atMax ? null : () => _changeMax(1),
          ),
        ],
      ),
    );
  }

  Widget _addonRow(Map<String, dynamic> addon) {
    final int id = addon['id'] as int;
    final int used = _usage[id] ?? 0;
    final String cmd = (addon['hardware_cmd'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(12)),
            child: Icon(AddonIcons.iconFor(addon['icon_key'] as String?), color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (addon['name'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'کد برد: $cmd   |   ${used > 0 ? 'در $used رک' : 'بدون رک'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ویرایش',
            icon: Icon(Icons.edit_outlined, color: Colors.blueGrey.shade700),
            onPressed: () => _openEditor(addon),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
            onPressed: () => _confirmDelete(addon),
          ),
        ],
      ),
    );
  }
}