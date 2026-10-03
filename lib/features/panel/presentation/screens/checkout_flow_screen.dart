import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/utils/extensions.dart';
import '../../../admin/presentation/widgets/product_thumb.dart';
import '../controllers/checkout_controller.dart';

/// صفحه تمام‌صفحه خرید: پرداخت با پوز ← تحویل کالا ← نتیجه (و پیام تماس با اپراتور برای پیگیری مالی در صورت نیاز).
/// منطق در CheckoutController است؛ این صفحه فقط وضعیت را نشان می‌دهد و با CheckoutOutcome بسته می‌شود.
class CheckoutFlowScreen extends StatefulWidget {
  final CheckoutController controller;

  const CheckoutFlowScreen({super.key, required this.controller});

  @override
  State<CheckoutFlowScreen> createState() => _CheckoutFlowScreenState();
}

class _CheckoutFlowScreenState extends State<CheckoutFlowScreen> {
  static const Color _ink = Color(0xFF2B3A47);

  Timer? _countdownTimer;
  int _countdown = 0;
  bool _popped = false;
  bool _cancelling = false;

  CheckoutController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
    _c.start();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _c.removeListener(_onChanged);
    _c.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});

    final outcome = _c.outcome;
    if (outcome != null) {
      if (!_popped) {
        _popped = true;
        _countdownTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final route = ModalRoute.of(context);
          final nav = Navigator.of(context);
          // اگر روی این صفحه مسیر دیگری باز شده باشد (مثلاً پنجره‌ای که با لمس همزمان باز شده)، اول بسته می‌شود
          // تا نتیجه خرید به مسیر خودش برگردد و صفحه گیر نکند
          if (route != null && !route.isCurrent) nav.popUntil((r) => r == route);
          nav.pop(outcome);
        });
      }
      return;
    }

    // پس از رد شدن کارت و تلاش مجدد، دکمه انصراف دوباره فعال می‌شود
    if (_c.phase != CheckoutPhase.paying) _cancelling = false;

    final secs = _c.autoCloseSeconds;
    if (secs > 0 && _countdownTimer == null) {
      _countdown = secs;
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _countdown--);
        if (_countdown <= 0) {
          t.cancel();
          _c.finish();
        }
      });
    }
  }

  // ---------------- رابط ----------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: _buildCard(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildContent(),
      ),
    );
  }

  List<Widget> _buildContent() {
    switch (_c.phase) {
      case CheckoutPhase.validating:
        return [
          _badge(Icons.shopping_cart_checkout, Colors.blueGrey, busy: true),
          _title('در حال بررسی سبد خرید...'),
        ];

      case CheckoutPhase.invalid:
        return [
          _badge(Icons.remove_shopping_cart_outlined, Colors.orange.shade800),
          _title('برخی کالاها دیگر قابل خرید نیستند'),
          _subtitle('این کالاها از سبد شما حذف می‌شوند. می‌توانید بقیه کالاها را دوباره پرداخت کنید.'),
          const SizedBox(height: 16),
          for (final issue in _c.issues) _issueRow(issue.name, issue.reason),
          const SizedBox(height: 20),
          _primaryButton('بازگشت به سبد خرید', _c.leave),
        ];

      case CheckoutPhase.paying:
        return [
          _badge(Icons.contactless_outlined, Colors.indigo.shade600, busy: true),
          _title('پرداخت با کارت بانکی'),
          _subtitle('مبلغ را روی دستگاه پوز تأیید کنید و کارت خود را بکشید یا نزدیک کنید.'),
          const SizedBox(height: 16),
          _amountBox(),
          const SizedBox(height: 12),
          ..._itemRows(),
          const SizedBox(height: 16),
          _secondaryButton(
            _cancelling ? 'در حال لغو...' : 'انصراف از پرداخت',
            _cancelling
                ? null
                : () {
                    setState(() => _cancelling = true);
                    _c.cancelPayment();
                  },
          ),
          const SizedBox(height: 12),
          _trackingCode(),
        ];

      case CheckoutPhase.payFailed:
        return _payFailedContent();

      case CheckoutPhase.dispensing:
        return [
          _badge(Icons.inventory_2_outlined, Colors.teal.shade600, busy: true),
          _title('پرداخت انجام شد'),
          _subtitle('کالاهای شما در حال تحویل است. لطفاً تا پایان کار منتظر بمانید.'),
          const SizedBox(height: 16),
          ..._itemRows(),
        ];

      case CheckoutPhase.done:
        return _resultContent();
    }
  }

  List<Widget> _payFailedContent() {
    final String title;
    final IconData icon;
    switch (_c.payFailKind) {
      case PayFailKind.declined:
        title = 'پرداخت انجام نشد';
        icon = Icons.credit_card_off_outlined;
        break;
      case PayFailKind.timeout:
        title = 'پاسخی از دستگاه پوز دریافت نشد';
        icon = Icons.timer_off_outlined;
        break;
      case PayFailKind.connection:
        title = 'ارتباط با دستگاه پوز برقرار نشد';
        icon = Icons.wifi_off_outlined;
        break;
      case PayFailKind.boardUnavailable:
        title = 'دستگاه موقتاً در دسترس نیست';
        icon = Icons.build_circle_outlined;
        break;
      case PayFailKind.internal:
        title = 'خطای داخلی دستگاه';
        icon = Icons.error_outline;
        break;
    }

    final bool uncertain = _c.payFailKind == PayFailKind.timeout || _c.payFailKind == PayFailKind.connection;
    return [
      _badge(icon, Colors.red.shade600),
      _title(title),
      _subtitle(_c.payFailMessage),
      if (uncertain) ...[
        const SizedBox(height: 10),
        _note(
          'اگر مبلغی از حساب شما کسر شده، کد پیگیری زیر را به اپراتور اعلام کنید.',
          Colors.orange.shade800,
        ),
      ],
      const SizedBox(height: 20),
      if (_c.canRetryPayment) ...[
        _primaryButton('تلاش مجدد', () => _c.retryPayment()),
        const SizedBox(height: 10),
      ],
      _c.canRetryPayment ? _secondaryButton('بازگشت به سبد خرید', _c.leave) : _primaryButton('بازگشت به سبد خرید', _c.leave),
      if (_c.hasTrackingCode) ...[
        const SizedBox(height: 12),
        _trackingCode(),
      ],
    ];
  }

  List<Widget> _resultContent() {
    final String title;
    final String subtitle;
    final IconData icon;
    final Color color;
    switch (_c.resultKind) {
      case ResultKind.success:
        title = 'خرید شما با موفقیت انجام شد';
        subtitle = 'کالای خود را از محفظه تحویل بردارید. از خرید شما سپاسگزاریم.';
        icon = Icons.check_circle_outline;
        color = Colors.green.shade600;
        break;
      case ResultKind.partial:
        title = 'بخشی از کالاها تحویل شد';
        subtitle = 'کالاهای تحویل‌نشده در لیست زیر مشخص است.';
        icon = Icons.warning_amber_rounded;
        color = Colors.orange.shade800;
        break;
      case ResultKind.failed:
        title = 'تحویل کالا انجام نشد';
        subtitle = 'متأسفانه کالایی تحویل داده نشد.';
        icon = Icons.error_outline;
        color = Colors.red.shade600;
        break;
      case ResultKind.unknown:
        title = 'ارتباط با دستگاه تحویل قطع شد';
        subtitle = 'نتیجه تحویل مشخص نیست. اگر کالایی تحویل نگرفتید، با اپراتور تماس بگیرید.';
        icon = Icons.help_outline;
        color = Colors.red.shade600;
        break;
    }

    final bool hasOwed = _c.owedAmount > 0;
    return [
      _badge(icon, color),
      _title(title),
      _subtitle(subtitle),
      const SizedBox(height: 16),
      ..._itemRows(showResult: true),
      if (_c.resultKind == ResultKind.success && _c.addons.isNotEmpty) ...[
        const SizedBox(height: 8),
        _addonsLine(),
      ],
      if (hasOwed) ...[
        const SizedBox(height: 14),
        _note(
          _c.resultKind == ResultKind.unknown
              ? 'پرداخت شما ثبت شده و نتیجه تحویل مشخص نیست. برای پیگیری مالی با اپراتور تماس بگیرید و کد پیگیری زیر را اعلام کنید.'
              : 'مبلغ ${_c.owedAmount.toRial} مربوط به کالاهای تحویل‌نشده است. برای پیگیری مالی با اپراتور تماس بگیرید و کد پیگیری زیر را اعلام کنید.',
          Colors.red.shade700,
        ),
      ],
      const SizedBox(height: 20),
      _primaryButton('پایان', _c.finish),
      if (_c.autoCloseSeconds > 0 && _countdownTimer != null && _countdown > 0) ...[
        const SizedBox(height: 8),
        Text(
          'بسته شدن خودکار تا $_countdown ثانیه دیگر',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
      const SizedBox(height: 12),
      _trackingCode(),
    ];
  }

  // ---------------- اجزای کوچک ----------------

  Widget _badge(IconData icon, Color color, {bool busy = false}) {
    return Center(
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle)),
            if (busy) SizedBox(width: 96, height: 96, child: CircularProgressIndicator(strokeWidth: 4, color: color)),
            Icon(icon, size: 44, color: color),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _ink),
      ),
    );
  }

  Widget _subtitle(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.8, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _amountBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFF3F5F8), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('مبلغ قابل پرداخت', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_c.totalAmount.toRial, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _ink)),
          ),
        ],
      ),
    );
  }

  List<Widget> _itemRows({bool showResult = false}) {
    return [for (final item in _c.items) _itemRow(item, showResult)];
  }

  Widget _itemRow(CheckoutItem item, bool showResult) {
    Widget? status;
    if (showResult) {
      switch (item.result) {
        case ItemResult.delivered:
          status = _statusChip(Icons.check_circle, 'تحویل شد', Colors.green.shade700);
          break;
        case ItemResult.failed:
          status = _statusChip(Icons.cancel, 'تحویل نشد', Colors.red.shade700);
          break;
        case ItemResult.unknown:
          status = _statusChip(Icons.help, 'نامعلوم', Colors.orange.shade800);
          break;
        case ItemResult.pending:
          break;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          ProductThumb(name: item.name, imagePath: item.imagePath, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
            ),
          ),
          const SizedBox(width: 8),
          Text(item.price.toRial, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          if (status != null) ...[const SizedBox(width: 10), status],
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _issueRow(String name, String reason) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: _ink))),
          Text(reason, style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
        ],
      ),
    );
  }

  Widget _addonsLine() {
    final text = _c.addons.map((a) => '${a['name']} (${a['count']} عدد)').join('،  ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, size: 18, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text('همراه سفارش: $text', style: TextStyle(fontSize: 13, color: Colors.teal.shade900))),
        ],
      ),
    );
  }

  Widget _note(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.8, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _trackingCode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('کد پیگیری: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(_c.trackingCode, style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _secondaryButton(String label, VoidCallback? onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.grey.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}