import 'dart:io';
import 'package:flutter/material.dart';

/// ابزارهای مشترک شبیه‌سازهای برد و پوز (برنامه‌های مستقل؛ بدون دیتابیس)

enum SimLogLevel { info, ok, warn, error }

class SimLogEntry {
  final DateTime time;
  final String title;
  final String detail;
  final SimLogLevel level;

  SimLogEntry(this.title, {this.detail = '', this.level = SimLogLevel.info}) : time = DateTime.now();
}

String simTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String simMoney(int value) {
  return value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

/// آدرس‌های IPv4 این سیستم (برای وارد کردن در «تنظیمات شبکه» پنل روی سیستم دیگر)
Future<List<String>> localIpv4Addresses() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    return [
      for (final i in interfaces)
        for (final a in i.addresses) a.address,
    ];
  } catch (_) {
    return [];
  }
}

ThemeData simTheme(Color seed) => ThemeData(useMaterial3: true, fontFamily: 'Vazir', colorSchemeSeed: seed);

Color simLevelColor(SimLogLevel level) {
  switch (level) {
    case SimLogLevel.ok:
      return Colors.green.shade700;
    case SimLogLevel.warn:
      return Colors.orange.shade800;
    case SimLogLevel.error:
      return Colors.red.shade700;
    case SimLogLevel.info:
      return Colors.blueGrey.shade700;
  }
}

/// فهرست رویدادها؛ entries از جدید به قدیم است
class SimLogView extends StatelessWidget {
  final List<SimLogEntry> entries;

  const SimLogView({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text('هنوز رویدادی ثبت نشده است', style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        final color = simLevelColor(e.level);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(simTime(e.time), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 10),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                    if (e.detail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: SelectableText(e.detail, style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.5)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// کارت وضعیت سرور: پورت، آدرس‌های این سیستم، دکمه شروع/توقف
class SimServerCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool running;
  final TextEditingController portController;
  final List<String> ips;
  final VoidCallback onToggle;

  const SimServerCard({
    super.key,
    required this.title,
    required this.icon,
    required this.running,
    required this.portController,
    required this.ips,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = running ? Colors.green.shade600 : Colors.grey.shade500;
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
                Icon(icon, size: 28, color: Colors.blueGrey.shade700),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        running ? 'در حال اجرا' : 'متوقف',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: portController,
                    enabled: !running,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'پورت',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onToggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: running ? Colors.red.shade600 : Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  icon: Icon(running ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                  label: Text(running ? 'توقف سرور' : 'شروع سرور'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('آدرس این سیستم (روی پنل وارد کنید):', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            if (ips.isEmpty)
              Text('آدرسی پیدا نشد (به شبکه وصل نیستید؟)', style: TextStyle(fontSize: 12, color: Colors.orange.shade800))
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: ips
                    .map(
                      (ip) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)),
                        child: SelectableText(ip, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}