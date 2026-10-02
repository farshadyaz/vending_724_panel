import 'package:flutter/material.dart';
import '../../../../core/database/settings_repository.dart';
import '../../../../core/hardware/hardware_models.dart';
import '../../../../core/hardware/ndjson_client.dart';
import '../../../../core/widgets/ip_pad.dart';

/// تنظیمات شبکه / سرور: آدرس و پورت برد و پوز + تست اتصال + حالت شبیه‌ساز داخلی
class NetworkSettingsDialog extends StatefulWidget {
  const NetworkSettingsDialog({super.key});

  @override
  State<NetworkSettingsDialog> createState() => _NetworkSettingsDialogState();
}

class _NetworkSettingsDialogState extends State<NetworkSettingsDialog> {
  static const Color _ink = Color(0xFF2B3A47);

  // اندیس فیلدها
  static const int _fBoardIp = 0;
  static const int _fBoardPort = 1;
  static const int _fPosIp = 2;
  static const int _fPosPort = 3;

  final SettingsRepository _settings = SettingsRepository();

  bool _loading = true;
  bool _saving = false;
  String _mode = SettingsRepository.hardwareModeNetwork;

  final List<String> _values = ['', '', '', ''];
  int _active = _fBoardIp;
  bool _fresh = true; // اولین کلید بعد از انتخاب فیلد، مقدار قبلی را جایگزین می‌کند

  DeviceCheck? _boardCheck;
  DeviceCheck? _posCheck;
  bool _boardTesting = false;
  bool _posTesting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await _settings.getHardwareMode();
    final boardIp = await _settings.getBoardIp();
    final boardPort = await _settings.getBoardPort();
    final posIp = await _settings.getPosIp();
    final posPort = await _settings.getPosPort();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _values[_fBoardIp] = boardIp;
      _values[_fBoardPort] = boardPort.toString();
      _values[_fPosIp] = posIp;
      _values[_fPosPort] = posPort.toString();
      _loading = false;
    });
  }

  void _toast(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green.shade700),
    );
  }

  bool get _activeIsPort => _active == _fBoardPort || _active == _fPosPort;

  // ---------------- ورودی ----------------

  void _selectField(int index) {
    setState(() {
      _active = index;
      _fresh = true;
    });
  }

  // با تغییر IP یا پورت یک دستگاه، نتیجه تست قبلی آن دستگاه نامعتبر می‌شود
  void _invalidateCheck(int fieldIndex) {
    if (fieldIndex == _fBoardIp || fieldIndex == _fBoardPort) {
      _boardCheck = null;
    } else {
      _posCheck = null;
    }
  }

  void _onKey(String k) {
    final bool isPort = _activeIsPort;
    if (isPort && k == '.') return;

    // اولین کلید بعد از انتخاب فیلد، مقدار قبلی را جایگزین می‌کند؛ کلید ردشده این حالت را مصرف نمی‌کند
    final String base = _fresh ? '' : _values[_active];
    final int maxLen = isPort ? 5 : 15;
    if (base.length >= maxLen) return;
    // شروع با نقطه یا دو نقطه پشت سر هم مجاز نیست
    if (k == '.' && (base.isEmpty || base.endsWith('.'))) return;

    setState(() {
      _values[_active] = base + k;
      _fresh = false;
      _invalidateCheck(_active);
    });
  }

  void _onBackspace() {
    setState(() {
      final v = _values[_active];
      if (v.isNotEmpty) _values[_active] = v.substring(0, v.length - 1);
      _fresh = false;
      _invalidateCheck(_active);
    });
  }

  void _onClear() {
    setState(() {
      _values[_active] = '';
      _fresh = false;
      _invalidateCheck(_active);
    });
  }

  // ---------------- تست اتصال ----------------

  Future<void> _test({required bool board}) async {
    final int ipIndex = board ? _fBoardIp : _fPosIp;
    final int portIndex = board ? _fBoardPort : _fPosPort;
    final String host = _values[ipIndex];
    final String portText = _values[portIndex];
    final int port = int.tryParse(portText) ?? 0;

    if (!SettingsRepository.isValidIpv4(host) || !SettingsRepository.isValidPort(port)) {
      setState(() {
        final c = const DeviceCheck(false, 'آدرس IP یا پورت نامعتبر است');
        if (board) {
          _boardCheck = c;
        } else {
          _posCheck = c;
        }
      });
      return;
    }

    setState(() {
      if (board) {
        _boardTesting = true;
        _boardCheck = null;
      } else {
        _posTesting = true;
        _posCheck = null;
      }
    });

    final result = await pingDevice(host, port);
    if (!mounted) return;

    // اگر در حین تست، IP یا پورت عوض شده، نتیجه مربوط به آدرس قبلی است و نمایش داده نمی‌شود
    final bool unchanged = _values[ipIndex] == host && _values[portIndex] == portText;
    setState(() {
      if (board) {
        _boardTesting = false;
        if (unchanged) _boardCheck = result;
      } else {
        _posTesting = false;
        if (unchanged) _posCheck = result;
      }
    });
  }

  // ---------------- ذخیره ----------------

  Future<void> _save() async {
    if (_saving) return;

    // اول اعتبارسنجی (بدون هیچ نوشتنی)؛ فقط اگر درست بود ذخیره می‌شود
    final int boardPort = int.tryParse(_values[_fBoardPort]) ?? 0;
    final int posPort = int.tryParse(_values[_fPosPort]) ?? 0;
    if (_mode == SettingsRepository.hardwareModeNetwork) {
      if (!SettingsRepository.isValidIpv4(_values[_fBoardIp]) || !SettingsRepository.isValidPort(boardPort)) {
        _toast('آدرس IP یا پورت برد نامعتبر است');
        return;
      }
      if (!SettingsRepository.isValidIpv4(_values[_fPosIp]) || !SettingsRepository.isValidPort(posPort)) {
        _toast('آدرس IP یا پورت پوز نامعتبر است');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_mode == SettingsRepository.hardwareModeNetwork) {
        await _settings.setNetwork(
          boardIp: _values[_fBoardIp],
          boardPort: boardPort,
          posIp: _values[_fPosIp],
          posPort: posPort,
        );
      }
      await _settings.setHardwareMode(_mode);

      if (!mounted) return;
      _toast('تنظیمات شبکه ذخیره شد', error: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('خطا در ذخیره: $e');
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _loading
              ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lan_outlined, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('تنظیمات شبکه / سرور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _modeToggle(),
                      const SizedBox(height: 12),
                      if (_mode == SettingsRepository.hardwareModeNetwork) ...[
                        _deviceCard(
                          title: 'برد الکترونیکی',
                          icon: Icons.memory,
                          ipIndex: _fBoardIp,
                          portIndex: _fBoardPort,
                          check: _boardCheck,
                          testing: _boardTesting,
                          onTest: () => _test(board: true),
                        ),
                        const SizedBox(height: 10),
                        _deviceCard(
                          title: 'دستگاه پوز',
                          icon: Icons.point_of_sale_outlined,
                          ipIndex: _fPosIp,
                          portIndex: _fPosPort,
                          check: _posCheck,
                          testing: _posTesting,
                          onTest: () => _test(board: false),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: IpPad(onKey: _onKey, onBackspace: _onBackspace, onClear: _onClear),
                        ),
                      ] else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'در حالت شبیه‌ساز داخلی، پرداخت و تحویل کالا بدون هیچ ارتباط شبکه‌ای و بدون اجرای برنامه‌های شبیه‌ساز، همیشه موفق شبیه‌سازی می‌شود. مناسب تست سریع روی یک سیستم.',
                            style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, height: 1.6),
                          ),
                        ),
                      const SizedBox(height: 14),
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

  Widget _modeToggle() {
    Widget seg(String mode, String label, IconData icon) {
      final selected = _mode == mode;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _mode = mode),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? _ink : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey.shade600),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: selected ? Colors.white : Colors.grey.shade700,
                    ),
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
          seg(SettingsRepository.hardwareModeNetwork, 'شبکه (برد و پوز)', Icons.lan_outlined),
          seg(SettingsRepository.hardwareModeMock, 'شبیه‌ساز داخلی', Icons.science_outlined),
        ],
      ),
    );
  }

  Widget _deviceCard({
    required String title,
    required IconData icon,
    required int ipIndex,
    required int portIndex,
    required DeviceCheck? check,
    required bool testing,
    required VoidCallback onTest,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueGrey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(flex: 3, child: _fieldBox(index: ipIndex, label: 'آدرس IP')),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _fieldBox(index: portIndex, label: 'پورت')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: testing ? null : onTest,
                icon: testing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check, size: 18),
                label: Text(testing ? 'در حال تست...' : 'تست اتصال'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: check == null
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          Icon(
                            check.ok ? Icons.check_circle : Icons.error_outline,
                            size: 18,
                            color: check.ok ? Colors.green.shade600 : Colors.red.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              check.latencyMs != null ? '${check.message} — ${check.latencyMs} ms' : check.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: check.ok ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldBox({required int index, required String label}) {
    final selected = _active == index;
    final value = _values[index];
    return InkWell(
      onTap: () => _selectField(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blueGrey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _ink : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            SizedBox(
              height: 26,
              child: Directionality(
                // اعداد و نقطه‌ها همیشه چپ‌به‌راست نمایش داده می‌شوند
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value.isEmpty ? '—' : value,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _ink),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}