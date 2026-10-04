// مسیر: lib/features/admin/presentation/screens/sales_report_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/database/report_repository.dart';
import '../../../../core/utils/csv_export.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/jalali.dart';
import '../widgets/order_detail_dialog.dart';
import '../widgets/report_widgets.dart';
import 'receivables_screen.dart';

/// آمار فروش: خلاصه بازه، فروش روزانه، به تفکیک محصول و رک، و فهرست سفارش‌ها
class SalesReportScreen extends StatefulWidget {
  /// نام فارسی نقش کاربر وارد‌شده؛ فقط برای ثبت «چه کسی مورد پیگیری را بست» هنگام رفتن به صفحه مطالبات
  final String roleName;
  final ReportRepository? repository;

  /// منبع زمان فعلی؛ فقط برای تست قابل جایگزینی است
  final DateTime Function() clock;

  const SalesReportScreen({super.key, this.roleName = 'مدیر', this.repository, this.clock = DateTime.now});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  static const int _pageSize = 40;

  late final ReportRepository _repo = widget.repository ?? ReportRepository();

  late List<ReportRange> _ranges = ReportRange.presets(widget.clock());
  String _rangeKey = 'today';
  int _tab = 0; // 0 روزانه، 1 محصولات، 2 رک‌ها، 3 سفارش‌ها
  OrderFilter _filter = OrderFilter.all;

  SalesSummary? _summary;
  List<DaySales> _days = const [];
  List<ProductSales> _products = const [];
  List<RackSales> _racks = const [];
  List<OrderRow> _orders = const [];
  bool _hasMoreOrders = false;
  bool _loadingMore = false;
  int _attentionCount = 0;

  int _pending = 0; // تعداد درخواست‌های در حال انجام
  bool get _loading => _pending > 0;
  String? _error;
  int _token = 0; // پاسخ بارگذاری‌های قدیمی (بعد از عوض شدن بازه) نادیده گرفته می‌شود
  int _ordersToken = 0; // همین کار برای فهرست سفارش‌ها (بعد از عوض شدن بازه یا فیلتر)

  ReportRange get _range => _ranges.firstWhere((r) => r.key == _rangeKey, orElse: () => _ranges.first);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int token = ++_token;
    final int ordersToken = ++_ordersToken;
    // «اکنون» با هر بار بارگذاری تازه می‌شود تا بعد از نیمه‌شب «امروز» درست بماند
    _ranges = ReportRange.presets(widget.clock());
    final range = _range;
    final filter = _filter;
    setState(() {
      _pending++;
      _error = null;
    });
    try {
      final summary = await _repo.salesSummary(range);
      final days = await _repo.salesByDay(range, now: widget.clock());
      final products = await _repo.salesByProduct(range);
      final racks = await _repo.salesByRack(range);
      final orders = await _repo.orders(range, filter: filter, limit: _pageSize + 1);
      final attention = await _repo.openAttentionCount();
      if (!mounted) return;
      setState(() {
        if (token == _token) {
          _summary = summary;
          _days = days;
          _products = products;
          _racks = racks;
          _attentionCount = attention;
        }
        if (ordersToken == _ordersToken) {
          _hasMoreOrders = orders.length > _pageSize;
          _orders = orders.take(_pageSize).toList();
        }
      });
    } catch (e) {
      if (mounted && token == _token) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _pending--);
    }
  }

  Future<void> _reloadOrders() async {
    final int ordersToken = ++_ordersToken;
    final range = _range;
    final filter = _filter;
    setState(() => _pending++);
    try {
      final orders = await _repo.orders(range, filter: filter, limit: _pageSize + 1);
      if (!mounted || ordersToken != _ordersToken) return;
      setState(() {
        _hasMoreOrders = orders.length > _pageSize;
        _orders = orders.take(_pageSize).toList();
      });
    } catch (e) {
      if (mounted && ordersToken == _ordersToken) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _pending--);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return; // وسط بارگذاری تازه، ادامه فهرست قدیمی نباید اضافه شود
    final int ordersToken = _ordersToken;
    final int offset = _orders.length;
    setState(() => _loadingMore = true);
    try {
      final next = await _repo.orders(_range, filter: _filter, limit: _pageSize + 1, offset: offset);
      if (!mounted || ordersToken != _ordersToken || offset != _orders.length) return;
      setState(() {
        _hasMoreOrders = next.length > _pageSize;
        _orders = [..._orders, ...next.take(_pageSize)];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خواندن ادامه سفارش‌ها ناموفق بود: $e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectRange(ReportRange r) {
    if (r.key == _rangeKey) return;
    setState(() => _rangeKey = r.key);
    _load();
  }

  Future<void> _openReceivables() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceivablesScreen(roleName: widget.roleName)),
    );
    if (mounted) _load();
  }

  // ---------------- رابط ----------------

  @override
  Widget build(BuildContext context) {
    return ReportPage(
      title: 'آمار فروش',
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'ذخیره سفارش‌های این بازه (اکسل)',
          onPressed: () => saveCsvAndNotify(
            context,
            name: 'vending_sales',
            buildCsv: () async => ReportCsv.orders(await _repo.orders(_range)),
          ),
        ),
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'به‌روزرسانی', onPressed: _loading ? null : _load),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_summary == null) {
      if (_error != null) return ErrorBox(message: _error!, onRetry: _load);
      return const Center(child: CircularProgressIndicator());
    }

    final s = _summary!;
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RangeChips(ranges: _ranges, selectedKey: _rangeKey, onSelected: _selectRange),
              const SizedBox(height: 14),
              if (_error != null) ...[
                _inlineError(),
                const SizedBox(height: 12),
              ],
              if (_attentionCount > 0) ...[
                _attentionBanner(),
                const SizedBox(height: 12),
              ],
              _summaryTiles(s),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: reportSegmentStyle(),
                  segments: const [
                    ButtonSegment(value: 0, label: Text('روزانه')),
                    ButtonSegment(value: 1, label: Text('محصولات')),
                    ButtonSegment(value: 2, label: Text('رک‌ها')),
                    ButtonSegment(value: 3, label: Text('سفارش‌ها')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
              ),
              const SizedBox(height: 12),
              _tabContent(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inlineError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text('به‌روزرسانی ناموفق بود: $_error', style: TextStyle(fontSize: 12, color: Colors.red.shade800))),
          TextButton(onPressed: _load, child: const Text('تلاش مجدد')),
        ],
      ),
    );
  }

  Widget _attentionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.notification_important_outlined, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_attentionCount مورد منتظر پیگیری اپراتور است (مطالبه مشتری یا سفارش نامعلوم)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange.shade900),
            ),
          ),
          TextButton(onPressed: _openReceivables, child: const Text('مشاهده')),
        ],
      ),
    );
  }

  Widget _summaryTiles(SalesSummary s) {
    final bool hasOpenOwed = s.owedOpenAmount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatTile(
          hero: true,
          label: 'فروش خالص',
          value: s.netRevenue.toRial,
          sub: s.soldOrders == 0 ? 'سفارش پرداخت‌شده‌ای در این بازه نیست' : 'از ${s.soldOrders} سفارش پرداخت‌شده',
        ),
        const SizedBox(height: 12),
        StatGrid(
          children: [
            StatTile(label: 'سفارش با تحویل کامل', value: '${s.completeOrders}'),
            StatTile(
              label: 'کالای تحویل‌شده',
              value: '${s.deliveredUnits}',
              sub: s.undeliveredUnits > 0 ? '${s.undeliveredUnits} کالا تحویل نشد' : null,
              subColor: s.undeliveredUnits > 0 ? Colors.red.shade700 : null,
            ),
            StatTile(
              label: 'مطالبه مشتریان',
              value: s.owedAmount.toRial,
              sub: s.partialOrders == 0
                  ? 'بدون مورد'
                  : hasOpenOwed
                      ? '${s.owedOpenAmount.toRial} هنوز تسویه نشده'
                      : 'همه تسویه شده',
              subColor: hasOpenOwed ? Colors.red.shade700 : null,
            ),
            StatTile(
              label: 'سفارش نامعلوم',
              value: '${s.uncertainOrders}',
              sub: s.uncertainOrders == 0 ? null : '${s.uncertainAmount.toRial} (در فروش حساب نشده)',
              subColor: s.uncertainOrders == 0 ? null : Colors.orange.shade800,
            ),
            StatTile(label: 'کارت ردشده', value: '${s.declinedOrders}'),
            StatTile(label: 'پرداخت لغوشده', value: '${s.cancelledOrders}'),
          ],
        ),
      ],
    );
  }

  Widget _tabContent() {
    switch (_tab) {
      case 0:
        return _daysTab();
      case 1:
        return _productsTab();
      case 2:
        return _racksTab();
      default:
        return _ordersTab();
    }
  }

  // ---------------- روزانه ----------------

  Widget _daysTab() {
    if (_days.isEmpty) return const SectionCard(child: EmptyBox('در این بازه فروشی ثبت نشده است', icon: Icons.bar_chart_outlined));
    final int max = _days.fold<int>(0, (m, d) => d.revenue > m ? d.revenue : m);
    return SectionCard(
      title: 'فروش خالص روزانه',
      child: Column(
        children: [
          for (final d in _days)
            _BarRow(
              title: '${Jalali.weekdayName(d.day)}  ${Jalali.formatDate(d.day)}',
              subtitle: d.orders == 0 ? 'بدون فروش' : '${d.orders} سفارش',
              valueText: d.revenue.toRial,
              fraction: max == 0 ? 0 : d.revenue / max,
            ),
        ],
      ),
    );
  }

  // ---------------- محصولات ----------------

  Widget _productsTab() {
    if (_products.isEmpty) return const SectionCard(child: EmptyBox('در این بازه کالایی تحویل داده نشده است', icon: Icons.inventory_2_outlined));
    final int max = _products.fold<int>(0, (m, p) => p.revenue > m ? p.revenue : m);
    return SectionCard(
      title: 'کالاهای تحویل‌شده به تفکیک محصول',
      child: Column(
        children: [
          for (final p in _products)
            _BarRow(
              title: p.name,
              subtitle: '${p.units} عدد',
              valueText: p.revenue.toRial,
              fraction: max == 0 ? 0 : p.revenue / max,
            ),
        ],
      ),
    );
  }

  // ---------------- رک‌ها ----------------

  Widget _racksTab() {
    if (_racks.isEmpty) return const SectionCard(child: EmptyBox('در این بازه فروشی ثبت نشده است', icon: Icons.grid_view_outlined));
    return SectionCard(
      title: 'به تفکیک رک (برای پیدا کردن رک‌های خراب)',
      child: Column(
        children: [
          for (final r in _racks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.physicalAddress == null ? 'رک ${r.rackNumber}' : 'رک ${r.rackNumber} (آدرس ${r.physicalAddress})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kReportInk),
                        ),
                      ),
                      Text(r.revenue.toRial, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kReportInk)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ),
                      const SizedBox(width: 8),
                      Text('${r.delivered} تحویل', style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w700)),
                      if (r.failed > 0) ...[
                        const SizedBox(width: 8),
                        Pill(text: '${r.failed} ناموفق', color: Colors.red.shade700, icon: Icons.build_circle_outlined),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- سفارش‌ها ----------------

  static const Map<OrderFilter, String> _filterLabels = {
    OrderFilter.all: 'همه',
    OrderFilter.complete: 'تحویل کامل',
    OrderFilter.settlement: 'مطالبه مشتری',
    OrderFilter.review: 'نیازمند بررسی',
    OrderFilter.failed: 'رد یا لغو',
  };

  Widget _ordersTab() {
    return SectionCard(
      title: 'سفارش‌ها',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in OrderFilter.values)
                ChoiceChip(
                  label: Text(_filterLabels[f]!),
                  selected: _filter == f,
                  onSelected: (_) {
                    if (_filter == f) return;
                    setState(() => _filter = f);
                    _reloadOrders();
                  },
                  labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _filter == f ? Colors.white : kReportInk),
                  selectedColor: Colors.blueGrey.shade700,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const EmptyBox('سفارشی با این شرایط پیدا نشد', icon: Icons.receipt_long_outlined)
          else ...[
            for (final o in _orders) _orderTile(o),
            if (_hasMoreOrders) LoadMoreButton(loading: _loadingMore || _loading, onPressed: _loadMore),
          ],
        ],
      ),
    );
  }

  Widget _orderTile(OrderRow o) {
    return InkWell(
      onTap: () => OrderDetailDialog.show(context, o.id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                OrderStatusPill(o.status),
                const Spacer(),
                Text(o.total.toRial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kReportInk)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.time == null ? '—' : Jalali.formatDateTime(o.time!),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                Text('${o.deliveredCount} از ${o.itemCount} کالا تحویل شد', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(child: LtrText(o.id, selectable: false, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                if (o.owed > 0)
                  Text(
                    'مطالبه: ${o.owed.toRial}${o.resolved ? ' (تسویه شد)' : ''}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: o.resolved ? Colors.grey.shade700 : Colors.red.shade700),
                  ),
              ],
            ),
            const Divider(height: 14),
          ],
        ),
      ),
    );
  }
}

/// یک ردیف با نوار افقی نسبی: تک‌رنگ، انتهای نوار گرد، متن‌ها به‌رنگ متن
class _BarRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String valueText;
  final double fraction;

  const _BarRow({required this.title, required this.subtitle, required this.valueText, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kReportInk)),
              ),
              const SizedBox(width: 8),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 12),
              Text(valueText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kReportInk)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: const Color(0xFFEEF1F5),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
                child: Container(color: Colors.blueGrey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}