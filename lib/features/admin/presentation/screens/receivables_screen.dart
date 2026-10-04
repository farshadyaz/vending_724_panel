// مسیر: lib/features/admin/presentation/screens/receivables_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/database/order_repository.dart';
import '../../../../core/database/report_repository.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/jalali.dart';
import '../widgets/order_detail_dialog.dart';
import '../widgets/report_widgets.dart';

/// مطالبات مشتریان و موارد نیازمند پیگیری اپراتور.
/// دستگاه بازگشت وجه ندارد: مشتری با کد پیگیری سفارش با اپراتور تماس می‌گیرد؛ اپراتور اینجا سفارش را با چند رقم آخر
/// کد پیدا می‌کند، مبلغ را بیرون از دستگاه با مشتری تسویه می‌کند و نتیجه واقعی را ثبت می‌کند تا حساب‌ها درست شود.
class ReceivablesScreen extends StatefulWidget {
  /// نام فارسی نقش کاربر وارد‌شده؛ در لاگ ثبت می‌شود که چه کسی مورد را بسته است
  final String roleName;
  final ReportRepository? repository;

  const ReceivablesScreen({super.key, required this.roleName, this.repository});

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  static const int _pageSize = 50;
  static const int _searchLimit = 30;

  late final ReportRepository _repo = widget.repository ?? ReportRepository();

  int _tab = 0; // 0 نیازمند پیگیری، 1 بسته‌شده
  AttentionGroup _group = AttentionGroup.all;
  String? _search; // رقم‌های جست‌وجوی کد پیگیری (null = حالت عادی)
  bool _searchTruncated = false; // نتیجه جست‌وجو بیشتر از حد نمایش بود

  AttentionStats _stats = const AttentionStats();
  List<OrderDetail> _items = const [];
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _loaded = false;
  int _pending = 0;
  String? _error;
  int _token = 0;
  final Set<String> _busy = {};

  bool get _loading => _pending > 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<OrderDetail>> _fetch({required int offset}) {
    if (_search != null) return _repo.searchOrdersByCode(_search!, limit: _searchLimit + 1);
    return _repo.attentionOrders(resolved: _tab == 1, group: _group, limit: _pageSize + 1, offset: offset);
  }

  Future<void> _load() async {
    final int token = ++_token;
    setState(() {
      _pending++;
      _error = null;
    });
    try {
      final stats = await _repo.attentionStats();
      final list = await _fetch(offset: 0);
      if (!mounted || token != _token) return;
      setState(() {
        _stats = stats;
        if (_search != null) {
          _hasMore = false;
          _searchTruncated = list.length > _searchLimit;
          _items = list.take(_searchLimit).toList();
        } else {
          _hasMore = list.length > _pageSize;
          _items = list.take(_pageSize).toList();
        }
        _loaded = true;
      });
    } catch (e) {
      if (mounted && token == _token) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _pending--);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _search != null) return;
    final int token = _token;
    final int offset = _items.length;
    setState(() => _loadingMore = true);
    try {
      final next = await _fetch(offset: offset);
      if (!mounted || token != _token || offset != _items.length) return;
      setState(() {
        _hasMore = next.length > _pageSize;
        _items = [..._items, ...next.take(_pageSize)];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خواندن ادامه فهرست ناموفق بود: $e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectTab(int tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _group = AttentionGroup.all;
      _items = const [];
      _hasMore = false;
    });
    _load();
  }

  void _selectGroup(AttentionGroup group) {
    if (group == _group) return;
    setState(() {
      _group = group;
      _items = const [];
      _hasMore = false;
    });
    _load();
  }

  Future<void> _openSearch() async {
    final digits = await showDialog<String>(context: context, builder: (_) => const _CodeSearchDialog());
    if (digits == null || digits.isEmpty || !mounted) return;
    setState(() {
      _search = digits;
      _items = const [];
      _hasMore = false;
    });
    _load();
  }

  void _clearSearch() {
    setState(() {
      _search = null;
      _searchTruncated = false;
      _items = const [];
      _hasMore = false;
    });
    _load();
  }

  // ---------------- بستن مورد ----------------

  static int _pendingSum(OrderDetail d) =>
      d.items.where((i) => i.status != ItemStatus.delivered).fold<int>(0, (s, i) => s + i.price);

  static List<ResolveOutcome> _outcomesFor(OrderDetail d) {
    return ReportRepository.allowedOutcomes(
      d.order.status,
      hasDeliveredItem: d.items.any((i) => i.status == ItemStatus.delivered),
      undeliveredCount: d.items.where((i) => i.status != ItemStatus.delivered).length,
    );
  }

  Future<void> _resolve(OrderDetail d) async {
    final o = d.order;
    if (_busy.contains(o.id)) return;

    final outcomes = _outcomesFor(d);
    if (outcomes.isEmpty) return;

    final outcome = await showDialog<ResolveOutcome>(
      context: context,
      builder: (_) => _OutcomeDialog(detail: d, outcomes: outcomes, pendingSum: _pendingSum(d)),
    );
    if (outcome == null || !mounted) return;

    var deliveredIds = <int>{};
    if (outcome == ResolveOutcome.partial) {
      final chosen = await showDialog<Set<int>>(context: context, builder: (_) => _PartialDialog(detail: d));
      if (chosen == null || chosen.isEmpty || !mounted) return;
      deliveredIds = chosen;
    }

    setState(() => _busy.add(o.id));
    try {
      final ok = await _repo.resolveOrder(o.id, by: widget.roleName, outcome: outcome, deliveredItemIds: deliveredIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? _doneMessage(outcome) : 'این مورد قبلاً بسته شده یا این نتیجه برای آن مجاز نیست'),
          backgroundColor: ok ? Colors.green.shade700 : Colors.orange.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ثبت نتیجه ناموفق بود: $e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
    if (mounted) await _load();
  }

  static String _doneMessage(ResolveOutcome outcome) {
    switch (outcome) {
      case ResolveOutcome.settled:
        return 'تسویه ثبت و مورد بسته شد';
      case ResolveOutcome.delivered:
        return 'ثبت شد: کالا تحویل شده بود؛ سفارش کامل و فروش حساب شد';
      case ResolveOutcome.partial:
        return 'ثبت شد: مبلغ مطالبه فقط برای کالاهای تحویل‌نشده به‌روز شد؛ بعد از تسویه ببندید';
      case ResolveOutcome.paidNotDelivered:
        return 'ثبت شد: مبلغ به‌عنوان مطالبه مشتری باز ماند؛ بعد از تسویه ببندید';
      case ResolveOutcome.notPaid:
        return 'ثبت شد: پرداخت انجام نشده بود و سفارش لغو شد';
    }
  }

  // ---------------- رابط ----------------

  @override
  Widget build(BuildContext context) {
    return ReportPage(
      title: 'مطالبات مشتریان',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'به‌روزرسانی', onPressed: _loading ? null : _load),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_loaded) {
      if (_error != null) return ErrorBox(message: _error!, onRetry: _load);
      return const Center(child: CircularProgressIndicator());
    }

    final bool searching = _search != null;
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                _inlineError(),
                const SizedBox(height: 12),
              ],
              _infoBox(),
              const SizedBox(height: 12),
              if (_stats.openOwedTotal > 0) ...[
                StatTile(
                  hero: true,
                  label: 'جمع مطالبات تسویه‌نشده',
                  value: _stats.openOwedTotal.toRial,
                  sub: 'مبلغ کالاهایی که مشتری پرداخته ولی تحویل نگرفته است',
                  subColor: Colors.red.shade700,
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _openSearch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kReportInk,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.search),
                label: const Text('جستجو با کد پیگیری مشتری', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              if (searching) ...[
                _searchBanner(),
                if (_searchTruncated) ...[
                  const SizedBox(height: 8),
                  _note('فقط $_searchLimit مورد جدیدتر نمایش داده شد؛ برای نتیجه دقیق‌تر رقم‌های بیشتری از کد را جستجو کنید.'),
                ],
                const SizedBox(height: 12),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: reportSegmentStyle(),
                    segments: [
                      ButtonSegment(value: 0, label: Text('نیازمند پیگیری (${_stats.open})')),
                      ButtonSegment(value: 1, label: Text('بسته‌شده (${_stats.closed})')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (v) => _selectTab(v.first),
                  ),
                ),
                const SizedBox(height: 12),
                if (_tab == 0) ...[
                  _groupChips(),
                  const SizedBox(height: 12),
                ],
              ],
              if (_items.isEmpty && !_loading && _error != null)
                SectionCard(child: _loadFailed())
              else if (_items.isEmpty && !_loading)
                SectionCard(child: _emptyState(searching))
              else
                for (final d in _items) ...[
                  _card(d),
                  const SizedBox(height: 12),
                ],
              if (_hasMore) LoadMoreButton(loading: _loadingMore, onPressed: _loadMore),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  /// بارگذاری ناموفق نباید شبیه «موردی نیست» دیده شود
  Widget _loadFailed() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 44, color: Colors.red.shade600),
          const SizedBox(height: 10),
          Text('خواندن فهرست ناموفق بود؛ این به معنی نبودن مورد نیست', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('تلاش مجدد')),
        ],
      ),
    );
  }

  Widget _emptyState(bool searching) {
    if (searching) return EmptyBox('سفارشی با این کد پیدا نشد', icon: Icons.search_off);
    if (_tab == 1) return const EmptyBox('هنوز موردی بسته نشده است', icon: Icons.inbox_outlined);
    return const EmptyBox('موردی برای پیگیری نیست', icon: Icons.task_alt_outlined);
  }

  Widget _note(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade300)),
      child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.7, color: Colors.orange.shade900, fontWeight: FontWeight.w600)),
    );
  }

  Widget _searchBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.blueGrey.shade700),
          const SizedBox(width: 8),
          const Text('نتیجه جستجو: ', style: TextStyle(fontSize: 13, color: kReportInk)),
          Expanded(child: LtrText(_search!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kReportInk))),
          TextButton.icon(onPressed: _clearSearch, icon: const Icon(Icons.close, size: 18), label: const Text('پاک کردن')),
        ],
      ),
    );
  }

  Widget _groupChips() {
    Widget chip(AttentionGroup g, String label, int count) {
      final selected = _group == g;
      return ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => _selectGroup(g),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : kReportInk),
        selectedColor: Colors.blueGrey.shade700,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(AttentionGroup.all, 'همه', _stats.open),
        chip(AttentionGroup.settlement, 'مطالبه مشتری', _stats.openSettlement),
        chip(AttentionGroup.review, 'نیازمند بررسی', _stats.openReview),
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

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.blueGrey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'دستگاه بازگشت وجه ندارد. مشتری برای کالای تحویل‌نشده با شما تماس می‌گیرد و کد پیگیری سفارش را اعلام می‌کند. '
              'چند رقم آخر کد را جستجو کنید، مبلغ را بیرون از دستگاه با مشتری تسویه کنید و سپس نتیجه را ثبت کنید.',
              style: TextStyle(fontSize: 12.5, height: 1.8, color: Colors.blueGrey.shade900),
            ),
          ),
        ],
      ),
    );
  }

  String _advice(OrderDetail d) {
    switch (d.order.status) {
      case OrderStatus.settlementDue:
        final bool unknown = d.items.any((i) => i.status == ItemStatus.unknown);
        return unknown
            ? 'ارتباط با برد هنگام تحویل قطع شد و نتیجه نامعلوم است. قبل از تسویه، محفظه تحویل و موجودی رک‌ها را بررسی کنید؛ اگر کالا تحویل شده بود همان را ثبت کنید.'
            : 'مشتری بابت کالای تحویل‌نشده پرداخت کرده است؛ مبلغ را با او تسویه کنید.';
      case OrderStatus.needsReview:
        return 'سفارش وسط کار متوقف شده (قطع برق یا بسته شدن برنامه). پرداخت را روی دستگاه پوز و تحویل کالا را بررسی و نتیجه را ثبت کنید.';
      case OrderStatus.paymentTimeout:
        return 'پوز پاسخ نداد. اگر مشتری می‌گوید مبلغ از حسابش کسر شده، «پرداخت شد ولی کالا تحویل نشد» را ثبت کنید؛ وگرنه «پرداخت انجام نشده بود».';
      case OrderStatus.posError:
        return 'ارتباط با پوز برقرار نشد و احتمالاً پرداختی انجام نشده است؛ فقط اگر مشتری ادعای کسر مبلغ دارد بررسی کنید و نتیجه را ثبت کنید.';
      default:
        return '';
    }
  }

  Widget _card(OrderDetail d) {
    final o = d.order;
    final style = orderStatusStyle(o.status);
    final bool settlement = o.status == OrderStatus.settlementDue;
    final bool busy = _busy.contains(o.id);
    final bool canResolve = !o.resolved && _outcomesFor(d).isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: o.resolved ? Colors.grey.shade200 : style.color.withValues(alpha: 0.4), width: o.resolved ? 1 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OrderStatusPill(o.status),
              const Spacer(),
              Text(o.time == null ? '—' : Jalali.formatDateTime(o.time!), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 12),
          if (settlement) ...[
            Text('مبلغ قابل تسویه با مشتری', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text(o.owed.toRial, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: o.resolved ? Colors.grey.shade700 : Colors.red.shade700)),
          ] else ...[
            Text('مبلغ سفارش', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text(o.total.toRial, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kReportInk)),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('کد پیگیری: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Expanded(child: LtrText(o.id, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kReportInk))),
            ],
          ),
          if (o.reference != null && o.reference!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Text('مرجع پوز: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Expanded(child: LtrText(o.reference!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kReportInk))),
                ],
              ),
            ),
          const SizedBox(height: 10),
          for (final item in d.items) _itemLine(item),
          if (canResolve && _advice(d).isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: style.color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
              child: Text(_advice(d), style: TextStyle(fontSize: 12.5, height: 1.7, color: style.color, fontWeight: FontWeight.w600)),
            ),
          ],
          if (o.resolved) ...[
            const SizedBox(height: 10),
            Text(
              'بسته شد: ${Jalali.formatDateTime(o.resolvedAt!)}${o.resolvedBy == null ? '' : '  —  ${o.resolvedBy}'}',
              style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => OrderDetailDialog.show(context, o.id),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('جزئیات'),
              ),
              const Spacer(),
              if (canResolve)
                FilledButton.icon(
                  onPressed: busy ? null : () => _resolve(d),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  icon: busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.task_alt, size: 20),
                  label: const Text('ثبت نتیجه'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemLine(OrderItemRow item) {
    final s = itemStatusStyle(item.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(s.icon, size: 16, color: s.color),
          const SizedBox(width: 6),
          Expanded(child: Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: kReportInk))),
          const SizedBox(width: 6),
          Text(item.price.toRial, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(width: 8),
          SizedBox(width: 58, child: Text(ReportLabels.item(item.status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.color))),
        ],
      ),
    );
  }
}

/// انتخاب نتیجه واقعی هنگام بستن یک مورد
class _OutcomeDialog extends StatelessWidget {
  final OrderDetail detail;
  final List<ResolveOutcome> outcomes;
  final int pendingSum;

  const _OutcomeDialog({required this.detail, required this.outcomes, required this.pendingSum});

  ({String title, String subtitle, IconData icon, Color color}) _describe(ResolveOutcome outcome) {
    final o = detail.order;
    final bool fromSettlement = o.status == OrderStatus.settlementDue;
    switch (outcome) {
      case ResolveOutcome.settled:
        return (
          title: 'تسویه شد',
          subtitle: 'مبلغ ${o.owed.toRial} با مشتری تسویه شد و مورد بسته می‌شود.',
          icon: Icons.task_alt,
          color: Colors.green.shade700,
        );
      case ResolveOutcome.delivered:
        return (
          title: fromSettlement ? 'کالا در واقع تحویل شده بود' : 'پرداخت شد و کالا تحویل شد',
          subtitle: 'مشتری کالا را گرفته و بدهی‌ای نیست. فروش کامل حساب می‌شود و کالاها از موجودی رک‌ها کم می‌شوند.',
          icon: Icons.inventory_2_outlined,
          color: Colors.green.shade700,
        );
      case ResolveOutcome.partial:
        return (
          title: 'بخشی از کالاها تحویل شده بود',
          subtitle: 'کالاهای تحویل‌شده را مشخص می‌کنید؛ مطالبه مشتری فقط برای بقیه می‌ماند و موجودی رک‌ها اصلاح می‌شود.',
          icon: Icons.rule,
          color: Colors.orange.shade800,
        );
      case ResolveOutcome.paidNotDelivered:
        return (
          title: 'پرداخت شد ولی کالا تحویل نشد',
          subtitle: 'مبلغ ${pendingSum.toRial} به‌عنوان مطالبه مشتری ثبت می‌شود و باز می‌ماند تا بعد از تسویه ببندید.',
          icon: Icons.payments_outlined,
          color: Colors.red.shade700,
        );
      case ResolveOutcome.notPaid:
        return (
          title: 'پرداخت انجام نشده بود',
          subtitle: 'سفارش لغو می‌شود و فروشی حساب نمی‌شود.',
          icon: Icons.block,
          color: Colors.blueGrey.shade700,
        );
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
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('نتیجه این مورد چه بود؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kReportInk)),
                const SizedBox(height: 6),
                LtrText(detail.order.id, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text('نتیجه ثبت‌شده قابل بازگشت نیست و حساب‌ها بر اساس آن اصلاح می‌شود.', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                for (final outcome in outcomes) ...[
                  _option(context, outcome),
                  const SizedBox(height: 10),
                ],
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext context, ResolveOutcome outcome) {
    final d = _describe(outcome);
    return Material(
      color: d.color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.pop(context, outcome),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: d.color.withValues(alpha: 0.4))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(d.icon, color: d.color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: d.color)),
                    const SizedBox(height: 4),
                    Text(d.subtitle, style: TextStyle(fontSize: 12.5, height: 1.7, color: Colors.grey.shade800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// انتخاب کالاهایی که واقعاً تحویل شده بودند (برای نتیجه «بخشی از کالاها تحویل شده بود»)
class _PartialDialog extends StatefulWidget {
  final OrderDetail detail;
  const _PartialDialog({required this.detail});

  @override
  State<_PartialDialog> createState() => _PartialDialogState();
}

class _PartialDialogState extends State<_PartialDialog> {
  final Set<int> _delivered = {};

  List<OrderItemRow> get _pending => widget.detail.items.where((i) => i.status != ItemStatus.delivered).toList();

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    final int remaining = pending.where((i) => !_delivered.contains(i.id)).fold<int>(0, (s, i) => s + i.price);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('کدام کالاها تحویل شده بود؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kReportInk)),
                    const SizedBox(height: 4),
                    Text('کالاهای تحویل‌شده را علامت بزنید. مطالبه مشتری فقط برای بقیه می‌ماند.', style: TextStyle(fontSize: 12.5, height: 1.7, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final item in pending)
                      CheckboxListTile(
                        value: _delivered.contains(item.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _delivered.add(item.id);
                          } else {
                            _delivered.remove(item.id);
                          }
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(item.productName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kReportInk)),
                        subtitle: Text(
                          '${item.price.toRial}  •  ${item.physicalAddress == null ? 'رک ${item.rackNumber}' : 'رک ${item.rackNumber} (آدرس ${item.physicalAddress})'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _delivered.length == pending.length
                          ? 'همه تحویل شده‌اند؛ مطالبه‌ای نمی‌ماند.'
                          : 'مطالبه مشتری پس از ثبت: ${remaining.toRial}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _delivered.length == pending.length ? Colors.green.shade700 : Colors.red.shade700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _delivered.isEmpty ? null : () => Navigator.pop(context, Set<int>.of(_delivered)),
                          style: FilledButton.styleFrom(backgroundColor: kReportInk, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                          icon: const Icon(Icons.task_alt),
                          label: const Text('ثبت'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// جستجوی کد پیگیری با کیپد عددی لمسی (دستگاه کیبورد ندارد)؛ چند رقم آخر کد کافی است
class _CodeSearchDialog extends StatefulWidget {
  const _CodeSearchDialog();

  @override
  State<_CodeSearchDialog> createState() => _CodeSearchDialogState();
}

class _CodeSearchDialogState extends State<_CodeSearchDialog> {
  static const int _minDigits = 3;
  String _digits = '';

  void _key(String d) {
    if (_digits.length >= 15) return;
    setState(() => _digits += d);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Widget _padKey(String label, VoidCallback onTap, {IconData? icon, Color? bg}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: bg ?? Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 54,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 24, color: kReportInk)
                    : Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: kReportInk)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _digits.length >= _minDigits;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('جستجوی کد پیگیری', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kReportInk)),
                const SizedBox(height: 6),
                Text('حداقل $_minDigits رقم از کد پیگیری مشتری را وارد کنید (چند رقم آخر کافی است).', style: TextStyle(fontSize: 12.5, height: 1.7, color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _digits.isEmpty ? '—' : _digits,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kReportInk, letterSpacing: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    children: [
                      for (final row in const [
                        ['1', '2', '3'],
                        ['4', '5', '6'],
                        ['7', '8', '9'],
                      ])
                        Row(children: [for (final d in row) _padKey(d, () => _key(d))]),
                      Row(
                        children: [
                          _padKey('', () => setState(() => _digits = ''), icon: Icons.delete_sweep_outlined, bg: Colors.red.shade50),
                          _padKey('0', () => _key('0')),
                          _padKey('', _backspace, icon: Icons.backspace_outlined, bg: Colors.blueGrey.shade50),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: ready ? () => Navigator.pop(context, _digits) : null,
                      style: FilledButton.styleFrom(backgroundColor: kReportInk, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12)),
                      icon: const Icon(Icons.search),
                      label: const Text('جستجو'),
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