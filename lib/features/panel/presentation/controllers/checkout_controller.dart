import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/bloc/machine/machine_bloc.dart';
import '../../../../core/bloc/machine/machine_event.dart';
import '../../../../core/database/order_repository.dart';
import '../../../../core/hardware/hardware_models.dart';
import '../../../../core/hardware/hardware_services.dart';
import '../../../../core/hardware/payment_gateway.dart';
import '../../../../core/utils/order_payload_builder.dart';

/// مرحله‌های چرخه خرید (چیزی که صفحه نشان می‌دهد)
enum CheckoutPhase {
  validating, // بررسی نهایی سبد
  invalid, // برخی کالاها دیگر قابل خرید نیستند
  paying, // منتظر پرداخت روی پوز
  payFailed, // پرداخت انجام نشد
  dispensing, // برد در حال تحویل کالا
  refunding, // بازگشت وجه
  done, // نتیجه نهایی
}

enum PayFailKind {
  declined, // کارت رد شد
  timeout, // پوز پاسخ نداد (وضعیت مبلغ نامعلوم)
  connection, // ارتباط با پوز برقرار نشد
  boardUnavailable, // قبل از پرداخت معلوم شد برد در دسترس نیست (هیچ پرداختی شروع نشده)
  internal, // خطای داخلی
}

enum ResultKind {
  success, // همه کالاها تحویل شد
  partial, // بخشی تحویل شد، مابقی برگشت داده می‌شود
  failed, // هیچ کالایی تحویل نشد
  unknown, // ارتباط با برد قطع شد؛ نتیجه نامعلوم، کل مبلغ برگشت داده می‌شود
}

enum ItemResult { pending, delivered, failed, unknown }

class CheckoutItem {
  final int rackNumber;
  final String name;
  final String? imagePath;
  final int price;
  ItemResult result = ItemResult.pending;

  CheckoutItem({required this.rackNumber, required this.name, required this.imagePath, required this.price});
}

/// نتیجه‌ای که صفحه خرید به صفحه انتخاب برمی‌گرداند
class CheckoutOutcome {
  /// پرداخت انجام شده و سفارش به نتیجه رسیده (تحویل یا بازگشت وجه) ← سبد خالی شود
  final bool clearCart;

  /// رک‌هایی که هنگام بررسی نهایی قابل خرید نبودند ← کالاهایشان از سبد برداشته شود
  final Set<int> invalidRacks;

  final String? message;

  const CheckoutOutcome({this.clearCart = false, this.invalidRacks = const <int>{}, this.message});
}

/// منطق کامل چرخه خرید: بررسی سبد ← ثبت سفارش ← پرداخت (پوز) ← تحویل (برد) ← ثبت نتیجه/موجودی ← بازگشت وجه.
/// صفحه فقط وضعیت را نشان می‌دهد؛ تمام تصمیم‌ها اینجاست تا بدون رابط کاربری هم قابل تست باشد.
class CheckoutController extends ChangeNotifier {
  final String orderId;
  final List<Map<String, dynamic>> cart;
  final int cartCapacity;
  final MachineBloc? machineBloc;
  final OrderRepository _repo;
  final Future<HardwareServices> Function() _loadServices;

  final List<CheckoutItem> items;
  final int totalAmount;
  final List<Map<String, dynamic>> addons;

  CheckoutController({
    required this.orderId,
    required List<Map<String, dynamic>> cart,
    required this.cartCapacity,
    this.machineBloc,
    OrderRepository? repository,
    Future<HardwareServices> Function()? servicesLoader,
  })  : cart = List<Map<String, dynamic>>.unmodifiable(cart),
        _repo = repository ?? OrderRepository(),
        _loadServices = servicesLoader ?? HardwareServices.load,
        items = [
          for (final c in cart)
            CheckoutItem(
              rackNumber: c['rack_number'] as int,
              name: (c['name'] ?? 'کالا').toString(),
              imagePath: c['image_path'] as String?,
              price: c['price'] as int,
            ),
        ],
        totalAmount = cart.fold<int>(0, (sum, c) => sum + (c['price'] as int)),
        addons = OrderPayloadBuilder.aggregateAddons(cart);

  CheckoutPhase _phase = CheckoutPhase.validating;
  PayFailKind _payFailKind = PayFailKind.internal;
  String _payFailMessage = '';
  ResultKind _resultKind = ResultKind.success;
  List<CartIssue> _issues = const [];
  int _refundAmount = 0;
  bool _refundSucceeded = true;
  bool _refundUncertain = false;
  String _refundMessage = '';
  bool _orderCreated = false;
  CheckoutOutcome? _outcome;

  HardwareServices? _services;
  PaymentSession? _session;
  String? _reference;
  bool _started = false;
  bool _disposed = false;

  CheckoutPhase get phase => _phase;
  PayFailKind get payFailKind => _payFailKind;
  String get payFailMessage => _payFailMessage;
  ResultKind get resultKind => _resultKind;
  List<CartIssue> get issues => _issues;

  /// مبلغی که باید به مشتری برگردد (۰ = بازگشت وجهی لازم نبود)
  int get refundAmount => _refundAmount;
  bool get refundSucceeded => _refundSucceeded;

  /// نتیجه بازگشت وجه نامعلوم است (ممکن است پوز مبلغ را برگردانده باشد)
  bool get refundUncertain => _refundUncertain;
  String get refundMessage => _refundMessage;

  /// کد پیگیری فقط وقتی معنا دارد که سفارش در دیتابیس ثبت شده باشد
  bool get hasTrackingCode => _orderCreated;

  /// بعد از غیر null شدن، صفحه خرید بسته می‌شود
  CheckoutOutcome? get outcome => _outcome;

  /// شناسه سفارش برای پیگیری مشتری با پشتیبانی
  String get trackingCode => orderId;

  /// مشتری فقط تا قبل از تأیید پرداخت می‌تواند انصراف بدهد
  bool get canCancelPayment => _phase == CheckoutPhase.paying;

  /// تلاش مجدد فقط وقتی امن است که مطمئن باشیم پرداختی انجام نشده: رد شدن کارت، یا در دسترس نبودن برد قبل از پرداخت.
  /// بعد از تایم‌اوت یا قطع ارتباط با پوز ممکن است پرداخت قبلی انجام شده باشد.
  bool get canRetryPayment =>
      _phase == CheckoutPhase.payFailed &&
      (_payFailKind == PayFailKind.declined || _payFailKind == PayFailKind.boardUnavailable);

  /// ثانیه‌های باقی‌مانده تا بسته شدن خودکار صفحه نتیجه (۰ = بسته نمی‌شود تا مشتری خودش دکمه را بزند)
  int get autoCloseSeconds {
    if (_phase != CheckoutPhase.done) return 0;
    if (_resultKind == ResultKind.success) return 10;
    if (_refundSucceeded) return 20;
    return 0;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setPhase(CheckoutPhase p) {
    _phase = p;
    _notify();
  }

  void _bloc(MachineEvent event) {
    machineBloc?.add(event);
  }

  Future<void> _safe(Future<void> Function() action, String what) async {
    try {
      await action();
    } catch (e) {
      debugPrint('CHECKOUT bookkeeping failed ($what): $e');
    }
  }

  void _close(CheckoutOutcome o) {
    if (_outcome != null) return;
    _outcome = o;
    _bloc(ResetMachine());
    _notify();
  }

  // ---------------- شروع ----------------

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _begin();
  }

  /// بررسی سبد ← بررسی در دسترس بودن برد ← ثبت سفارش ← پرداخت.
  /// برد قبل از پرداخت بررسی می‌شود تا اگر خاموش یا قطع است، مشتری اصلاً پولی نپردازد و بازگشت وجه لازم نشود.
  Future<void> _begin() async {
    _setPhase(CheckoutPhase.validating);

    try {
      _services ??= await _loadServices();

      final issues = await _repo.validateCart(cart);
      if (issues.isNotEmpty) {
        _issues = issues;
        _setPhase(CheckoutPhase.invalid);
        return;
      }

      DeviceCheck board;
      try {
        board = await _services!.board.ping();
      } catch (e) {
        board = DeviceCheck(false, 'خطا: $e');
      }
      if (!board.ok) {
        await _repo.log('HARD', 'BOARD_UNAVAILABLE', 'قبل از پرداخت $orderId برد در دسترس نبود: ${board.message}');
        _failPayment(
          PayFailKind.boardUnavailable,
          'دستگاه موقتاً قادر به تحویل کالا نیست و مبلغی از شما کسر نشده است. چند لحظه بعد دوباره تلاش کنید.',
        );
        return;
      }

      await _repo.createOrder(orderId: orderId, cart: cart, cartCapacity: cartCapacity);
      _orderCreated = true;
    } catch (e) {
      debugPrint('CHECKOUT start failed: $e');
      await _repo.log('HARD', 'CHECKOUT_START', 'شروع خرید ناموفق بود ($orderId): $e');
      _failPayment(PayFailKind.internal, 'خطای داخلی دستگاه؛ مبلغی از شما کسر نشده است. لطفاً به سبد بازگردید.');
      return;
    }

    await _repo.log('OP', 'ORDER_CREATED', 'سفارش $orderId ثبت شد؛ ${items.length} کالا، مبلغ $totalAmount ریال');

    // ماشین حالت: Idle ← Selection ← Payment
    _bloc(ScreenTouched());
    _bloc(PaymentInitiated());

    await _startPayment();
  }

  // ---------------- پرداخت ----------------

  Future<void> _startPayment() async {
    _setPhase(CheckoutPhase.paying);

    PaymentResult result;
    try {
      final session = _services!.payment.startPayment(orderId: orderId, amount: totalAmount);
      _session = session;
      result = await session.result;
    } catch (e) {
      result = PaymentResult(PaymentStatus.connectionError, message: 'خطای ارتباط با پوز: $e');
    }
    _session = null;

    await _onPaymentResult(result);
  }

  Future<void> _onPaymentResult(PaymentResult result) async {
    switch (result.status) {
      case PaymentStatus.approved:
        _reference = result.reference;
        // وضعیت سفارش و آیتم‌ها (دوباره «در انتظار تحویل») در یک تراکنش
        await _safe(() => _repo.markPaid(orderId, reference: result.reference), 'paid');
        await _repo.log('OP', 'PAY_APPROVED', 'پرداخت $orderId تأیید شد؛ مرجع پوز: ${result.reference ?? '-'}');
        _bloc(PaymentSuccess());
        await _dispense();
        break;

      case PaymentStatus.cancelled:
        await _safe(() => _repo.setPaymentStatus(orderId, OrderStatus.cancelled), 'cancelled');
        await _safe(() => _repo.setAllItemsStatus(orderId, ItemStatus.cancelled), 'items-cancelled');
        await _repo.log('SOFT', 'PAY_CANCELLED', 'پرداخت $orderId لغو شد');
        _close(const CheckoutOutcome(message: 'پرداخت لغو شد؛ سبد خرید شما حفظ شده است'));
        break;

      case PaymentStatus.declined:
        await _safe(() => _repo.setPaymentStatus(orderId, OrderStatus.declined), 'declined');
        await _safe(() => _repo.setAllItemsStatus(orderId, ItemStatus.cancelled), 'items-cancelled');
        await _repo.log('SOFT', 'PAY_DECLINED', 'پرداخت $orderId رد شد: ${result.message}');
        _failPayment(PayFailKind.declined, result.message.isEmpty ? 'پرداخت رد شد' : result.message);
        break;

      case PaymentStatus.timeout:
        await _safe(() => _repo.setPaymentStatus(orderId, OrderStatus.paymentTimeout), 'pay-timeout');
        await _safe(() => _repo.setAllItemsStatus(orderId, ItemStatus.cancelled), 'items-cancelled');
        await _repo.log('HARD', 'PAY_TIMEOUT', 'پوز برای $orderId پاسخ نداد؛ وضعیت مبلغ نامعلوم است');
        _failPayment(PayFailKind.timeout, 'پاسخی از پوز دریافت نشد');
        break;

      case PaymentStatus.connectionError:
        await _safe(() => _repo.setPaymentStatus(orderId, OrderStatus.posError), 'pos-error');
        await _safe(() => _repo.setAllItemsStatus(orderId, ItemStatus.cancelled), 'items-cancelled');
        await _repo.log('HARD', 'POS_CONNECTION', 'ارتباط با پوز برای $orderId برقرار نشد: ${result.message}');
        _failPayment(PayFailKind.connection, 'ارتباط با دستگاه پوز برقرار نشد');
        break;
    }
  }

  void _failPayment(PayFailKind kind, String message) {
    _payFailKind = kind;
    _payFailMessage = message;
    _setPhase(CheckoutPhase.payFailed);
  }

  /// انصراف مشتری هنگام انتظار برای پرداخت
  void cancelPayment() {
    if (!canCancelPayment) return;
    _session?.cancel();
  }

  /// تلاش مجدد: بعد از رد شدن کارت (همان سفارش) یا بعد از در دسترس نبودن برد (از ابتدا)
  Future<void> retryPayment() async {
    if (!canRetryPayment) return;

    if (_payFailKind == PayFailKind.boardUnavailable) {
      await _begin(); // اولین کارش تغییر مرحله است، پس لمس دوباره دکمه تلاش دوم را شروع نمی‌کند
      return;
    }

    _setPhase(CheckoutPhase.paying); // قفل همزمان: لمس دوباره دکمه، پرداخت دوم شروع نمی‌کند
    try {
      // سفارش قبل از صحبت با پوز دوباره PENDING می‌شود؛ اگر وسط تلاش مجدد برق برود، بعد از راه‌اندازی علامت می‌خورد
      await _repo.reopenForPayment(orderId);
    } catch (e) {
      await _repo.log('HARD', 'CHECKOUT_RETRY', 'بازگرداندن سفارش $orderId به حالت پرداخت ناموفق بود: $e');
      _failPayment(PayFailKind.internal, 'خطای داخلی دستگاه؛ مبلغی از شما کسر نشده است. لطفاً به سبد بازگردید.');
      return;
    }
    await _repo.log('OP', 'PAY_RETRY', 'تلاش مجدد پرداخت $orderId');
    await _startPayment();
  }

  /// بازگشت به سبد از صفحه خطا
  void leave() {
    if (_phase == CheckoutPhase.invalid) {
      _close(CheckoutOutcome(
        invalidRacks: {for (final i in _issues) i.rackNumber},
        message: 'کالاهای قابل خرید نبودند از سبد حذف شدند',
      ));
    } else if (_phase == CheckoutPhase.payFailed) {
      _close(const CheckoutOutcome());
    }
  }

  // ---------------- تحویل ----------------

  Future<void> _dispense() async {
    _setPhase(CheckoutPhase.dispensing);

    final commands = OrderPayloadBuilder.buildCommands(cart);
    DispenseResult result;
    try {
      result = await _services!.board.dispense(orderId: orderId, commands: commands, addons: addons);
    } catch (e) {
      result = DispenseResult(orderId: orderId, status: DispenseStatus.connectionError, message: 'خطای ارتباط با برد: $e');
    }

    if (result.fatal) {
      await _onFatalDispense(result);
    } else {
      await _onDispenseResult(result);
    }

    _setPhase(CheckoutPhase.done);
  }

  /// تایم‌اوت یا قطع ارتباط با برد: نتیجه تحویل نامعلوم است ← طبق سند معماری کل مبلغ برگردانده می‌شود
  Future<void> _onFatalDispense(DispenseResult result) async {
    _bloc(HardwareTimeoutOccurred());
    _resultKind = ResultKind.unknown;
    for (final item in items) {
      item.result = ItemResult.unknown;
    }

    await _safe(
      () => _repo.recordDispense(orderId, const <int, int>{}, undeliveredStatus: ItemStatus.unknown),
      'record-fatal',
    );
    await _repo.log(
      'HARD',
      result.status == DispenseStatus.timeout ? 'BOARD_TIMEOUT' : 'BOARD_CONNECTION',
      'تحویل سفارش $orderId نامعلوم ماند (${result.message}); کل مبلغ برگشت داده می‌شود و موجودی رک‌ها بررسی شود',
    );

    await _refund(totalAmount, full: true);
  }

  Future<void> _onDispenseResult(DispenseResult result) async {
    _bloc(HardwareResponded());

    final Map<int, int> deliveredByRack = {for (final r in result.racks) r.rackNumber: r.delivered};

    // نتیجه هر آیتم: از هر رک، به تعداد تحویل‌شده آیتم‌های اول تحویل‌شده حساب می‌شود
    final Map<int, int> used = {};
    int undeliveredAmount = 0;
    int deliveredCount = 0;
    for (final item in items) {
      final int index = used[item.rackNumber] ?? 0;
      used[item.rackNumber] = index + 1;
      if (index < (deliveredByRack[item.rackNumber] ?? 0)) {
        item.result = ItemResult.delivered;
        deliveredCount++;
      } else {
        item.result = ItemResult.failed;
        undeliveredAmount += item.price;
      }
    }

    await _safe(
      () => _repo.recordDispense(orderId, deliveredByRack, undeliveredStatus: ItemStatus.failed),
      'record-dispense',
    );

    for (final r in result.racks) {
      if (r.errorCode == 'H-1001') {
        await _repo.log('HARD', 'H-1001', 'خرابی موتور رک ${r.rackNumber} در سفارش $orderId؛ رک قرنطینه شد');
      } else if (!r.complete) {
        await _repo.log('SOFT', 'RACK_FAILED', 'رک ${r.rackNumber} در سفارش $orderId کامل تحویل نداد (${r.status}, ${r.delivered}/${r.requested})');
      }
    }

    if (undeliveredAmount == 0) {
      _resultKind = ResultKind.success;
      await _repo.log('OP', 'ORDER_DONE', 'سفارش $orderId کامل تحویل شد');
      return;
    }

    _resultKind = deliveredCount > 0 ? ResultKind.partial : ResultKind.failed;
    await _repo.log('OP', 'ORDER_PARTIAL', 'سفارش $orderId: $deliveredCount از ${items.length} کالا تحویل شد؛ بازگشت وجه $undeliveredAmount ریال');
    await _refund(undeliveredAmount, full: deliveredCount == 0);
  }

  // ---------------- بازگشت وجه ----------------

  Future<void> _refund(int amount, {required bool full}) async {
    _setPhase(CheckoutPhase.refunding);
    _refundAmount = amount;

    RefundResult r;
    try {
      r = await _services!.payment.refund(orderId: orderId, amount: amount, reference: _reference);
    } catch (e) {
      r = RefundResult(false, 'خطای بازگشت وجه: $e');
    }
    _refundSucceeded = r.success;
    _refundUncertain = !r.success && r.uncertain;
    _refundMessage = r.message;

    if (r.success) {
      await _safe(
        () => _repo.setRefund(orderId, status: full ? OrderStatus.refunded : OrderStatus.partialRefunded, amount: amount),
        'refund-ok',
      );
      await _repo.log('OP', 'REFUND_OK', 'بازگشت وجه $amount ریال برای $orderId انجام شد');
    } else if (r.uncertain) {
      await _safe(() => _repo.setRefund(orderId, status: OrderStatus.refundUnknown, amount: 0), 'refund-unknown');
      await _repo.log(
        'HARD',
        'REFUND_UNKNOWN',
        'نتیجه بازگشت وجه $amount ریال برای $orderId نامعلوم است (${r.message}); اول وضعیت در پوز بررسی شود تا دوبار برگشت زده نشود',
      );
    } else {
      await _safe(() => _repo.setRefund(orderId, status: OrderStatus.refundFailed, amount: 0), 'refund-failed');
      await _repo.log('HARD', 'REFUND_FAILED', 'بازگشت وجه $amount ریال برای $orderId ناموفق بود (${r.message}); باید دستی پیگیری شود');
    }
  }

  // ---------------- پایان ----------------

  /// مشتری نتیجه را دید (دکمه پایان یا بسته شدن خودکار)
  void finish() {
    if (_phase != CheckoutPhase.done) return;
    _close(const CheckoutOutcome(clearCart: true));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session?.cancel();
    super.dispose();
  }
}