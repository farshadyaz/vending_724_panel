// مسیر: lib/features/admin/presentation/screens/system_logs_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/database/report_repository.dart';
import '../../../../core/utils/csv_export.dart';
import '../../../../core/utils/jalali.dart';
import '../widgets/order_detail_dialog.dart';
import '../widgets/report_widgets.dart';

/// نمایش لاگ‌های سیستم؛ با category مشخص می‌شود لاگ‌های پنل (خرید، پرداخت، پوز) یا برد الکترونیکی (تحویل کالا، موتور رک‌ها) نمایش داده شود.
class SystemLogsScreen extends StatefulWidget {
  final LogCategory category;
  final ReportRepository? repository;

  /// منبع زمان فعلی؛ فقط برای تست قابل جایگزینی است
  final DateTime Function() clock;

  const SystemLogsScreen({super.key, required this.category, this.repository, this.clock = DateTime.now});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  static const int _pageSize = 100;
  static const List<String> _types = ['HARD', 'SOFT', 'OP'];

  late final ReportRepository _repo = widget.repository ?? ReportRepository();

  late List<ReportRange> _ranges = ReportRange.presets(widget.clock());
  String _rangeKey = 'last7';
  String? _type;
  String? _code;

  List<LogEntry> _logs = const [];
  Map<String, int> _counts = const {};
  List<String> _codes = const [];
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _exporting = false;
  bool _loaded = false;
  int _pending = 0;
  String? _error;
  int _token = 0;

  bool get _loading => _pending > 0;
  bool get _isBoard => widget.category == LogCategory.board;
  ReportRange get _range => _ranges.firstWhere((r) => r.key == _rangeKey, orElse: () => _ranges.first);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int token = ++_token;
    _ranges = ReportRange.presets(widget.clock());
    final range = _range;
    setState(() {
      _pending++;
      _error = null;
    });
    try {
      final codes = await _repo.logCodes(category: widget.category, range: range, type: _type);
      // اگر کد انتخاب‌شده در این بازه یا نوع وجود ندارد، فیلتر کد برداشته می‌شود
      final String? code = (_code != null && codes.contains(_code)) ? _code : null;
      final counts = await _repo.logCountsByType(category: widget.category, range: range, code: code);
      final logs = await _repo.logs(
        category: widget.category,
        range: range,
        type: _type,
        code: code,
        limit: _pageSize + 1,
      );
      if (!mounted || token != _token) return;
      setState(() {
        _codes = codes;
        _code = code;
        _counts = counts;
        _hasMore = logs.length > _pageSize;
        _logs = logs.take(_pageSize).toList();
        _loaded = true;
      });
    } catch (e) {
      if (mounted && token == _token) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _pending--);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return; // وسط بارگذاری تازه، ادامه فهرست قدیمی نباید اضافه شود
    final int token = _token;
    final int offset = _logs.length;
    setState(() => _loadingMore = true);
    try {
      final next = await _repo.logs(
        category: widget.category,
        range: _range,
        type: _type,
        code: _code,
        limit: _pageSize + 1,
        offset: offset,
      );
      if (!mounted || token != _token || offset != _logs.length) return;
      setState(() {
        _hasMore = next.length > _pageSize;
        _logs = [..._logs, ...next.take(_pageSize)];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خواندن ادامه لاگ‌ها ناموفق بود: $e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectRange(ReportRange r) {
    if (r.key == _rangeKey) return;
    setState(() => _rangeKey = r.key);
    _load();
  }

  void _selectType(String? type) {
    if (type == _type) return;
    setState(() => _type = type);
    _load();
  }

  void _selectCode(String? code) {
    if (code == _code) return;
    setState(() => _code = code);
    _load();
  }

  Future<void> _purge() async {
    final int count;
    try {
      count = await _repo.oldLogsCount(days: 90, now: widget.clock());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خواندن تعداد لاگ‌ها ناموفق بود: $e'), backgroundColor: Colors.red.shade700));
      return;
    }
    if (!mounted) return;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('لاگ قدیمی‌ای برای حذف نیست'), backgroundColor: Colors.blueGrey.shade700));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('پاک‌سازی لاگ‌های قدیمی', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text(
            '$count لاگ «عملیاتی» و «هشدار» قدیمی‌تر از ۹۰ روز حذف می‌شود. لاگ‌های «خطای جدی» و خود سفارش‌ها هیچ‌وقت حذف نمی‌شوند.\n\n'
            'اگر نسخه پشتیبان می‌خواهید، اول با بازه «همه» فایل اکسل ذخیره کنید. حذف قابل بازگشت نیست. ادامه می‌دهید؟',
            style: const TextStyle(fontSize: 14, height: 1.8),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('حذف شود'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final n = await _repo.purgeOldLogs(days: 90, now: widget.clock());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n == 0 ? 'لاگ قدیمی‌ای برای حذف نبود' : '$n لاگ قدیمی حذف شد'), backgroundColor: Colors.green.shade700));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('پاک‌سازی ناموفق بود: $e'), backgroundColor: Colors.red.shade700));
    }
  }

  /// ذخیره همه لاگ‌های این فیلتر (بدون سقف تعداد)؛ تا پایان کار دکمه غیرفعال است
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await saveCsvAndNotify(
        context,
        name: _isBoard ? 'vending_board_logs' : 'vending_panel_logs',
        buildCsv: () async => ReportCsv.logs(
          await _repo.logs(category: widget.category, range: _range, type: _type, code: _code),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---------------- رابط ----------------

  @override
  Widget build(BuildContext context) {
    return ReportPage(
      title: _isBoard ? 'خطا / لاگ برد الکترونیکی' : 'لاگ‌های سیستم پنل',
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'ذخیره لاگ‌های این فیلتر (اکسل)',
          onPressed: _exporting ? null : _export,
        ),
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'به‌روزرسانی', onPressed: _loading ? null : _load),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (v) {
            if (v == 'purge') _purge();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'purge', child: Text('پاک‌سازی لاگ‌های قدیمی')),
          ],
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_loaded) {
      if (_error != null) return ErrorBox(message: _error!, onRetry: _load);
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RangeChips(ranges: _ranges, selectedKey: _rangeKey, onSelected: _selectRange),
              const SizedBox(height: 12),
              _typeChips(),
              const SizedBox(height: 12),
              _codeDropdown(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _inlineError(),
              ],
              const SizedBox(height: 12),
              SectionCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: _logs.isEmpty
                    ? const EmptyBox('لاگی با این فیلتر پیدا نشد', icon: Icons.text_snippet_outlined)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < _logs.length; i++) ...[
                            _logRow(_logs[i]),
                            if (i != _logs.length - 1) const Divider(height: 1),
                          ],
                          if (_hasMore) LoadMoreButton(loading: _loadingMore || _loading, onPressed: _loadMore),
                          const SizedBox(height: 8),
                        ],
                      ),
              ),
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

  Widget _typeChips() {
    final int all = _counts.values.fold<int>(0, (s, n) => s + n);
    Widget chip(String? type, String label, int count) {
      final bool selected = _type == type;
      return ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => _selectType(type),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : kReportInk),
        selectedColor: type == null ? Colors.blueGrey.shade700 : logTypeColor(type),
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(null, 'همه', all),
        for (final t in _types) chip(t, ReportLabels.type(t), _counts[t] ?? 0),
      ],
    );
  }

  Widget _codeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _code,
          isExpanded: true,
          hint: const Text('همه رویدادها'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('همه رویدادها')),
            for (final c in _codes)
              DropdownMenuItem<String?>(
                value: c,
                child: Text(ReportLabels.logCode.containsKey(c) ? '${ReportLabels.code(c)}  ($c)' : c, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _selectCode,
        ),
      ),
    );
  }

  Widget _logRow(LogEntry log) {
    final color = logTypeColor(log.type);
    final orderId = log.orderId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(logTypeIcon(log.type), size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ReportLabels.code(log.code),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(text: ReportLabels.type(log.type), color: color),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  log.time == null ? log.rawTime : '${Jalali.weekdayName(log.time!)}  ${Jalali.formatDate(log.time!)}  ${Jalali.formatTimeWithSeconds(log.time!)}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                SelectableText(log.description, style: TextStyle(fontSize: 13, height: 1.6, color: Colors.grey.shade900)),
                if (orderId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('مشاهده سفارش'),
                      onPressed: () => OrderDetailDialog.show(context, orderId),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${log.id}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}