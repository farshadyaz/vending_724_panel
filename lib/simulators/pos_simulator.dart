// شبیه‌ساز دستگاه پوز
// اجرا:  flutter run -t lib/simulators/pos_simulator.dart -d windows
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/hardware/hardware_models.dart';
import 'sim_common.dart';

void main() {
  runApp(const PosSimulatorApp());
}

class PosSimulatorApp extends StatelessWidget {
  const PosSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شبیه‌ساز دستگاه پوز',
      theme: simTheme(Colors.indigo),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const PosSimulatorScreen(),
    );
  }
}

enum PosMode { manual, autoApprove, autoDecline, timeout, drop }

/// یک درخواست پرداخت که منتظر تصمیم اپراتور شبیه‌ساز است
class _PendingPayment {
  final Socket socket;
  final String orderId;
  final int amount;
  final DateTime time = DateTime.now();

  _PendingPayment(this.socket, this.orderId, this.amount);
}

class PosSimulatorScreen extends StatefulWidget {
  const PosSimulatorScreen({super.key});

  @override
  State<PosSimulatorScreen> createState() => _PosSimulatorScreenState();
}

class _PosSimulatorScreenState extends State<PosSimulatorScreen> {
  final TextEditingController _portCtrl = TextEditingController(text: '8090');

  ServerSocket? _server;
  final Set<Socket> _clients = {};
  List<String> _ips = [];

  PosMode _mode = PosMode.manual;
  double _delaySec = 2;

  final List<_PendingPayment> _pending = [];
  final List<SimLogEntry> _log = [];

  int _refCounter = 1000;
  int _approvedCount = 0;
  int _approvedTotal = 0;
  int _declinedCount = 0;

  bool _disposed = false;

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
    _disposed = true;
    _server?.close();
    final open = _clients.toList();
    _clients.clear();
    for (final c in open) {
      c.destroy();
    }
    _portCtrl.dispose();
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
      _addLog('پوز روی پورت $port آماده است', detail: _ips.isEmpty ? '' : 'آدرس‌ها: ${_ips.join('  |  ')}', level: SimLogLevel.ok);
    } on SocketException catch (e) {
      _addLog('راه‌اندازی ناموفق', detail: '${e.message} (پورت در حال استفاده است؟)', level: SimLogLevel.error);
    }
  }

  Future<void> _stop() async {
    final server = _server;
    setState(() {
      _server = null;
      _pending.clear();
    });
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
      onDone: () => _onClientClosed(socket),
      onError: (Object _) => _onClientClosed(socket),
      cancelOnError: true,
    );
  }

  // اگر پنل در حین انتظار اتصال را ببندد (مثلاً دکمه لغو پرداخت)، درخواست در انتظار لغو می‌شود
  void _onClientClosed(Socket socket) {
    _clients.remove(socket);
    socket.destroy(); // بستن کامل سوکت سمت سرور (جلوگیری از نشت)
    if (_disposed || !mounted) return;
    final cancelled = _pending.where((p) => p.socket == socket).toList();
    if (cancelled.isEmpty) return;
    setState(() => _pending.removeWhere((p) => p.socket == socket));
    for (final p in cancelled) {
      _addLog('پنل پرداخت را لغو کرد', detail: '${p.orderId} — ${simMoney(p.amount)} ریال', level: SimLogLevel.warn);
    }
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

    final String type = (msg['type'] ?? '').toString();
    switch (type) {
      case HwProtocol.ping:
        _send(socket, {'type': HwProtocol.pong, 'device': 'POS_SIM'});
        _addLog('PING از $remote');
        break;
      case HwProtocol.pay:
        await _handlePay(socket, remote, msg);
        break;
      default:
        _addLog('پیام ناشناخته از $remote', detail: line, level: SimLogLevel.warn);
        _send(socket, {'type': 'ERROR', 'message': 'نوع پیام ناشناخته'});
    }
  }

  Future<void> _handlePay(Socket socket, String remote, Map<String, dynamic> msg) async {
    final String orderId = (msg['order_id'] ?? '').toString();
    final int amount = (msg['amount'] as num?)?.toInt() ?? 0;
    final p = _PendingPayment(socket, orderId, amount);

    _addLog('درخواست پرداخت از $remote', detail: '$orderId — ${simMoney(amount)} ریال');

    switch (_mode) {
      case PosMode.manual:
        setState(() => _pending.insert(0, p));
        break;
      case PosMode.autoApprove:
      case PosMode.autoDecline:
        await Future.delayed(Duration(milliseconds: (_delaySec * 1000).round()));
        if (!mounted || !_clients.contains(socket)) return;
        _respondPay(
          p,
          _mode == PosMode.autoApprove ? 'APPROVED' : 'DECLINED',
          _mode == PosMode.autoApprove ? 'تأیید خودکار' : 'موجودی کارت کافی نیست',
        );
        break;
      case PosMode.timeout:
        _addLog('حالت تایم‌اوت: پاسخی ارسال نمی‌شود', detail: orderId, level: SimLogLevel.warn);
        break;
      case PosMode.drop:
        _addLog('حالت قطع ارتباط: اتصال بسته شد', detail: orderId, level: SimLogLevel.warn);
        socket.destroy();
        _clients.remove(socket);
        break;
    }
  }

  void _respondPay(_PendingPayment p, String status, String message) {
    if (!_clients.contains(p.socket)) {
      _addLog('پنل دیگر متصل نیست', detail: p.orderId, level: SimLogLevel.warn);
      if (mounted) setState(() => _pending.remove(p));
      return;
    }
    final bool approved = status == 'APPROVED';
    final String? reference = approved ? 'POS-${_refCounter++}' : null;
    _send(p.socket, {
      'type': HwProtocol.payResult,
      'order_id': p.orderId,
      'status': status,
      'reference': reference,
      'message': message,
    });
    setState(() {
      _pending.remove(p);
      if (approved) {
        _approvedCount++;
        _approvedTotal += p.amount;
      } else if (status == 'DECLINED') {
        _declinedCount++;
      }
    });
    _addLog(
      approved ? 'پرداخت تأیید شد' : (status == 'DECLINED' ? 'پرداخت رد شد' : 'پرداخت لغو شد'),
      detail: '${p.orderId} — ${simMoney(p.amount)} ریال${reference == null ? '' : ' — مرجع: $reference'}',
      level: approved ? SimLogLevel.ok : SimLogLevel.error,
    );
  }

  void _resetCounters() {
    setState(() {
      _approvedCount = 0;
      _approvedTotal = 0;
      _declinedCount = 0;
    });
  }

  // ---------------- رابط ----------------

  static const Map<PosMode, String> _modeTitles = {
    PosMode.manual: 'دستی (تصمیم با من)',
    PosMode.autoApprove: 'تأیید خودکار',
    PosMode.autoDecline: 'رد خودکار',
    PosMode.timeout: 'تایم‌اوت (بدون پاسخ)',
    PosMode.drop: 'قطع ارتباط',
  };

  static const Map<PosMode, String> _modeHelp = {
    PosMode.manual: 'هر درخواست پرداخت در همین صفحه نمایش داده می‌شود و با دکمه‌ها تأیید، رد یا لغو می‌کنید.',
    PosMode.autoApprove: 'همه پرداخت‌ها پس از تأخیر تعیین‌شده تأیید می‌شوند.',
    PosMode.autoDecline: 'همه پرداخت‌ها با پیام «موجودی کارت کافی نیست» رد می‌شوند.',
    PosMode.timeout: 'درخواست دریافت می‌شود ولی پاسخی داده نمی‌شود؛ پنل باید تایم‌اوت پرداخت را نشان دهد.',
    PosMode.drop: 'اتصال بلافاصله بعد از دریافت درخواست قطع می‌شود.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        title: const Text('شبیه‌ساز دستگاه پوز', style: TextStyle(fontWeight: FontWeight.bold)),
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
          title: 'سرور پوز',
          icon: Icons.point_of_sale_outlined,
          running: _running,
          portController: _portCtrl,
          ips: _ips,
          onToggle: _toggleServer,
        ),
        const SizedBox(height: 12),
        if (_pending.isNotEmpty) ...[
          for (final p in _pending) _pendingCard(p),
          const SizedBox(height: 4),
        ],
        _card(
          title: 'رفتار پوز',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PosMode.values
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
              if (_mode == PosMode.autoApprove || _mode == PosMode.autoDecline) ...[
                const SizedBox(height: 6),
                Text('تأخیر پاسخ: ${_delaySec.toStringAsFixed(1)} ثانیه', style: const TextStyle(fontSize: 13)),
                Slider(
                  value: _delaySec,
                  min: 0,
                  max: 15,
                  divisions: 30,
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
            children: [
              Row(
                children: [
                  _stat('پرداخت موفق', '$_approvedCount', Colors.green.shade700),
                  _stat('پرداخت ردشده', '$_declinedCount', Colors.red.shade700),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat('جمع دریافتی (ریال)', simMoney(_approvedTotal), Colors.green.shade800),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pendingCard(_PendingPayment p) {
    return Card(
      elevation: 0,
      color: Colors.indigo.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.indigo.shade200, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('درخواست پرداخت ${p.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(simTime(p.time), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                '${simMoney(p.amount)} ریال',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _respondPay(p, 'APPROVED', 'تأیید توسط اپراتور شبیه‌ساز'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('تأیید پرداخت'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _respondPay(p, 'DECLINED', 'موجودی کارت کافی نیست'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600, padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.highlight_off),
                    label: const Text('رد کارت'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _respondPay(p, 'CANCELLED', 'لغو توسط کاربر روی پوز'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey.shade600, padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('لغو'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}