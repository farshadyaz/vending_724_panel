// شبیه‌ساز برد الکترونیکی وندینگ
// اجرا:  flutter run -t lib/simulators/board_simulator.dart -d windows
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/hardware/hardware_models.dart';
import 'sim_common.dart';

void main() {
  runApp(const BoardSimulatorApp());
}

class BoardSimulatorApp extends StatelessWidget {
  const BoardSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شبیه‌ساز برد الکترونیکی',
      theme: simTheme(Colors.teal),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const BoardSimulatorScreen(),
    );
  }
}

enum BoardMode { success, jam, random, timeout, drop }

class BoardSimulatorScreen extends StatefulWidget {
  const BoardSimulatorScreen({super.key});

  @override
  State<BoardSimulatorScreen> createState() => _BoardSimulatorScreenState();
}

class _BoardSimulatorScreenState extends State<BoardSimulatorScreen> {
  final TextEditingController _portCtrl = TextEditingController(text: '8080');
  final TextEditingController _jamCtrl = TextEditingController();
  final Random _rng = Random();

  ServerSocket? _server;
  final Set<Socket> _clients = {};
  List<String> _ips = [];

  BoardMode _mode = BoardMode.success;
  double _delaySec = 2;
  double _failProb = 0.3;

  final List<SimLogEntry> _log = [];
  int _orders = 0;
  int _delivered = 0;
  int _failed = 0;
  final Map<String, int> _addonTotals = {}; // «نام (کد)» ← تعداد کل

  bool get _running => _server != null;

  @override
  void initState() {
    super.initState();
    localIpv4Addresses().then((ips) {
      if (mounted) setState(() => _ips = ips);
    });
  }

  @override
  void dispose() {
    _server?.close();
    final open = _clients.toList();
    _clients.clear();
    for (final c in open) {
      c.destroy();
    }
    _portCtrl.dispose();
    _jamCtrl.dispose();
    super.dispose();
  }

  void _addLog(String title, {String detail = '', SimLogLevel level = SimLogLevel.info}) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, SimLogEntry(title, detail: detail, level: level));
      if (_log.length > 300) _log.removeRange(300, _log.length);
    });
  }

  // ---------------- سرور ----------------

  Future<void> _toggleServer() async {
    if (_running) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port < 1 || port > 65535) {
      _addLog('پورت نامعتبر است', level: SimLogLevel.error);
      return;
    }
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      server.listen(
        _onClient,
        onError: (Object e) => _addLog('خطای سرور', detail: '$e', level: SimLogLevel.error),
      );
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() => _server = server);
      _addLog('برد روی پورت $port آماده است', detail: _ips.isEmpty ? '' : 'آدرس‌ها: ${_ips.join('  |  ')}', level: SimLogLevel.ok);
    } on SocketException catch (e) {
      _addLog('راه‌اندازی ناموفق', detail: '${e.message} (پورت در حال استفاده است؟)', level: SimLogLevel.error);
    }
  }

  Future<void> _stop() async {
    final server = _server;
    setState(() => _server = null);
    await server?.close();
    for (final c in _clients.toList()) {
      c.destroy();
    }
    _clients.clear();
    _addLog('سرور متوقف شد');
  }

  void _onClient(Socket socket) {
    _clients.add(socket);
    final remote = socket.remoteAddress.address;
    socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) => _handleLine(socket, remote, line),
      onDone: () {
        _clients.remove(socket);
        socket.destroy(); // بستن کامل سوکت سمت سرور (جلوگیری از نشت)
      },
      onError: (Object _) {
        _clients.remove(socket);
        socket.destroy();
      },
      cancelOnError: true,
    );
  }

  void _send(Socket socket, Map<String, dynamic> message) {
    try {
      socket.write('${jsonEncode(message)}\n');
    } catch (_) {
      // اتصال بسته شده است
    }
  }

  // ---------------- پیام‌ها ----------------

  Future<void> _handleLine(Socket socket, String remote, String line) async {
    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) throw const FormatException('آبجکت JSON نیست');
      msg = Map<String, dynamic>.from(decoded);
    } catch (e) {
      _addLog('پیام نامعتبر از $remote', detail: line, level: SimLogLevel.warn);
      _send(socket, {'type': 'ERROR', 'message': 'JSON نامعتبر'});
      return;
    }

    final String type = (msg['type'] ?? (msg.containsKey('commands') ? HwProtocol.dispense : '')).toString();
    switch (type) {
      case HwProtocol.ping:
        _send(socket, {'type': HwProtocol.pong, 'device': 'BOARD_SIM'});
        _addLog('PING از $remote');
        break;
      case HwProtocol.dispense:
        await _handleDispense(socket, remote, msg);
        break;
      default:
        _addLog('پیام ناشناخته از $remote', detail: line, level: SimLogLevel.warn);
        _send(socket, {'type': 'ERROR', 'message': 'نوع پیام ناشناخته'});
    }
  }

  Set<int> _jamRacks() {
    return _jamCtrl.text
        .split(RegExp(r'[,\s،]+'))
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

  Future<void> _handleDispense(Socket socket, String remote, Map<String, dynamic> msg) async {
    final String orderId = (msg['order_id'] ?? '').toString();
    final commands = (msg['commands'] is List ? msg['commands'] as List : const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final addons = (msg['addons'] is List ? msg['addons'] as List : const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    final cmdText = commands.map((c) => 'رک ${c['rack_number']} × ${c['qty']}').join('، ');
    final addonText = addons.isEmpty ? 'بدون افزودنی' : addons.map((a) => '${a['name']} ×${a['count']}').join('، ');
    _addLog(
      'سفارش $orderId از $remote',
      detail: 'کالاها: ${cmdText.isEmpty ? '-' : cmdText}\nافزودنی‌ها: $addonText',
    );

    if (_mode == BoardMode.timeout) {
      _addLog('حالت تایم‌اوت: پاسخی ارسال نمی‌شود', detail: orderId, level: SimLogLevel.warn);
      return;
    }
    if (_mode == BoardMode.drop) {
      _addLog('حالت قطع ارتباط: اتصال بسته شد', detail: orderId, level: SimLogLevel.warn);
      socket.destroy();
      _clients.remove(socket);
      return;
    }

    await Future.delayed(Duration(milliseconds: (_delaySec * 1000).round()));
    if (!mounted) return;

    final jam = _jamRacks();
    final List<Map<String, dynamic>> results = [];
    int deliveredUnits = 0;
    int failedUnits = 0;
    for (final c in commands) {
      final int rack = (c['rack_number'] as num?)?.toInt() ?? 0;
      final int qty = (c['qty'] as num?)?.toInt() ?? 1;
      final bool broken = (_mode == BoardMode.jam && jam.contains(rack)) ||
          (_mode == BoardMode.random && _rng.nextDouble() < _failProb);
      results.add({
        'rack_number': rack,
        'requested': qty,
        'delivered': broken ? 0 : qty,
        'status': broken ? 'MOTOR_JAM' : 'OK',
        'error_code': broken ? 'H-1001' : null,
      });
      if (broken) {
        failedUnits += qty;
      } else {
        deliveredUnits += qty;
      }
    }

    final String status = failedUnits == 0 ? 'OK' : (deliveredUnits == 0 ? 'FAILED' : 'PARTIAL');
    _send(socket, {
      'type': HwProtocol.dispenseResult,
      'order_id': orderId,
      'status': status,
      'results': results,
      'addons': [
        for (final a in addons) {'addon_id': a['addon_id'], 'cmd': a['cmd'], 'count': a['count'], 'status': 'OK'},
      ],
    });

    setState(() {
      _orders++;
      _delivered += deliveredUnits;
      _failed += failedUnits;
      for (final a in addons) {
        final key = '${a['name']} (کد ${a['cmd']})';
        _addonTotals[key] = (_addonTotals[key] ?? 0) + ((a['count'] as num?)?.toInt() ?? 0);
      }
    });

    _addLog(
      status == 'OK' ? 'تحویل کامل: $orderId' : (status == 'FAILED' ? 'تحویل ناموفق: $orderId' : 'تحویل ناقص: $orderId'),
      detail: results
          .map((r) => 'رک ${r['rack_number']}: ${r['status']} (${r['delivered']}/${r['requested']})')
          .join('\n'),
      level: status == 'OK' ? SimLogLevel.ok : SimLogLevel.error,
    );
  }

  void _resetCounters() {
    setState(() {
      _orders = 0;
      _delivered = 0;
      _failed = 0;
      _addonTotals.clear();
    });
  }

  // ---------------- رابط ----------------

  static const Map<BoardMode, String> _modeTitles = {
    BoardMode.success: 'موفق',
    BoardMode.jam: 'خرابی موتور در رک‌های مشخص',
    BoardMode.random: 'خرابی تصادفی',
    BoardMode.timeout: 'تایم‌اوت (بدون پاسخ)',
    BoardMode.drop: 'قطع ارتباط',
  };

  static const Map<BoardMode, String> _modeHelp = {
    BoardMode.success: 'همه کالاها پس از تأخیر تعیین‌شده، تحویل‌شده اعلام می‌شوند.',
    BoardMode.jam: 'رک‌هایی که شماره‌شان را وارد کنید، خطای H-1001 (MOTOR_JAM) می‌دهند و کالایی تحویل نمی‌شود.',
    BoardMode.random: 'هر رک با احتمال تعیین‌شده خراب می‌شود (برای تست تحویل ناقص و بازگشت وجه جزئی).',
    BoardMode.timeout: 'سفارش دریافت می‌شود ولی هیچ پاسخی داده نمی‌شود؛ پنل باید تایم‌اوت کند و بازگشت وجه کامل بدهد.',
    BoardMode.drop: 'اتصال بلافاصله بعد از دریافت سفارش قطع می‌شود.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        title: const Text('شبیه‌ساز برد الکترونیکی', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final controls = _buildControls();
          final logPanel = _buildLogPanel();
          if (constraints.maxWidth >= 900) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: SingleChildScrollView(child: controls)),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: logPanel),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              controls,
              const SizedBox(height: 16),
              SizedBox(height: 420, child: logPanel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimServerCard(
          title: 'سرور برد',
          icon: Icons.memory,
          running: _running,
          portController: _portCtrl,
          ips: _ips,
          onToggle: _toggleServer,
        ),
        const SizedBox(height: 12),
        _card(
          title: 'رفتار برد',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BoardMode.values
                    .map(
                      (m) => ChoiceChip(
                        label: Text(_modeTitles[m]!),
                        selected: _mode == m,
                        onSelected: (_) => setState(() => _mode = m),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(_modeHelp[_mode]!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.6)),
              if (_mode == BoardMode.jam) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _jamCtrl,
                  decoration: InputDecoration(
                    labelText: 'شماره رک‌های خراب (با کاما جدا کنید؛ مثل 3,5,12)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              if (_mode == BoardMode.random) ...[
                const SizedBox(height: 6),
                Text('احتمال خرابی هر رک: ${(_failProb * 100).round()}٪', style: const TextStyle(fontSize: 13)),
                Slider(
                  value: _failProb,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: (v) => setState(() => _failProb = v),
                ),
              ],
              if (_mode != BoardMode.timeout && _mode != BoardMode.drop) ...[
                const SizedBox(height: 6),
                Text('زمان تحویل: ${_delaySec.toStringAsFixed(1)} ثانیه', style: const TextStyle(fontSize: 13)),
                Slider(
                  value: _delaySec,
                  min: 0,
                  max: 9,
                  divisions: 18,
                  onChanged: (v) => setState(() => _delaySec = v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: 'آمار این نشست',
          trailing: TextButton.icon(
            onPressed: _resetCounters,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('صفر کردن'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _stat('سفارش‌ها', _orders, Colors.blueGrey.shade700),
                  _stat('کالای تحویل‌شده', _delivered, Colors.green.shade700),
                  _stat('کالای ناموفق', _failed, Colors.red.shade700),
                ],
              ),
              const SizedBox(height: 10),
              Text('جمع افزودنی‌های دریافتی:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              _addonTotals.isEmpty
                  ? Text('—', style: TextStyle(color: Colors.grey.shade500))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _addonTotals.entries
                          .map(
                            (e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text('${e.key}: ${e.value}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          )
                          .toList(),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogPanel() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(
              children: [
                const Expanded(child: Text('رویدادها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                TextButton.icon(
                  onPressed: () => setState(_log.clear),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('پاک کردن'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: SimLogView(entries: _log)),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child, Widget? trailing}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}