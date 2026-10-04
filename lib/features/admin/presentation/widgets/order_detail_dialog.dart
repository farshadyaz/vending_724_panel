// مسیر: lib/features/admin/presentation/widgets/order_detail_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/database/report_repository.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/jalali.dart';
import 'report_widgets.dart';

/// جزئیات یک سفارش: وضعیت، مبلغ‌ها، کالاها و همه لاگ‌هایی که شناسه این سفارش را دارند
class OrderDetailDialog extends StatefulWidget {
  final String orderId;
  final ReportRepository? repository;

  const OrderDetailDialog({super.key, required this.orderId, this.repository});

  static Future<void> show(BuildContext context, String orderId) {
    return showDialog<void>(context: context, builder: (_) => OrderDetailDialog(orderId: orderId));
  }

  @override
  State<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<OrderDetailDialog> {
  late final ReportRepository _repo = widget.repository ?? ReportRepository();
  OrderDetail? _detail;
  bool _loading = true;
  bool _missing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.orderDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _missing = d == null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('جزئیات سفارش', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kReportInk)),
                    ),
                    IconButton(icon: const Icon(Icons.close), tooltip: 'بستن', onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return SizedBox(height: 260, child: ErrorBox(message: _error!, onRetry: _load));
    }
    if (_missing || _detail == null) {
      return const SizedBox(height: 200, child: EmptyBox('این سفارش پیدا نشد'));
    }

    final d = _detail!;
    final o = d.order;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OrderStatusPill(o.status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  o.time == null ? '—' : '${Jalali.weekdayName(o.time!)}  ${Jalali.formatDateTime(o.time!)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _kv('کد پیگیری', LtrText(o.id, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kReportInk))),
          _kv('مبلغ سفارش', Text(o.total.toRial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kReportInk))),
          if (o.owed > 0)
            _kv(
              'مبلغ مطالبه مشتری',
              Text(o.owed.toRial, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
            ),
          if (o.isSold)
            _kv('فروش خالص', Text(o.net.toRial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kReportInk))),
          _kv(
            'کد مرجع پوز',
            (o.reference == null || o.reference!.isEmpty)
                ? Text('—', style: TextStyle(color: Colors.grey.shade600))
                : LtrText(o.reference!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kReportInk)),
          ),
          if (o.resolved)
            _kv(
              'بسته شد',
              Text('${Jalali.formatDateTime(o.resolvedAt!)}  —  ${o.resolvedBy ?? ''}', style: const TextStyle(fontSize: 13, color: kReportInk)),
            ),
          const SizedBox(height: 16),
          Text('کالاها', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 6),
          if (d.items.isEmpty)
            Text('کالایی ثبت نشده است', style: TextStyle(color: Colors.grey.shade600))
          else
            for (final item in d.items) _itemRow(item),
          const SizedBox(height: 16),
          Text('رویدادهای این سفارش', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 6),
          if (d.logs.isEmpty)
            Text('رویدادی ثبت نشده است', style: TextStyle(color: Colors.grey.shade600))
          else
            for (final log in d.logs) _logRow(log),
        ],
      ),
    );
  }

  Widget _kv(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: value)),
        ],
      ),
    );
  }

  Widget _itemRow(OrderItemRow item) {
    final style = itemStatusStyle(item.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(style.icon, size: 18, color: style.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kReportInk)),
                Text(
                  item.physicalAddress == null ? 'رک ${item.rackNumber}' : 'رک ${item.rackNumber} (آدرس ${item.physicalAddress})',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(item.price.toRial, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(ReportLabels.item(item.status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: style.color)),
          ),
        ],
      ),
    );
  }

  Widget _logRow(LogEntry log) {
    final color = logTypeColor(log.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(logTypeIcon(log.type), size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ReportLabels.code(log.code)}  •  ${log.time == null ? '—' : Jalali.formatTimeWithSeconds(log.time!)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                SelectableText(log.description, style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}