/// پروتکل و مدل‌های مشترک بین پنل، شبیه‌سازها و (در آینده) برد و پوز واقعی.
///
/// قالب پیام‌ها: هر پیام یک آبجکت JSON در یک خط است (UTF-8) که با '\n' تمام می‌شود.
///
/// برد:
///   پنل ← برد : {"type":"DISPENSE","order_id":"ORD-1","commands":[{"rack_number":1,"physical_address":1001,"qty":2}],
///                "addons":[{"addon_id":1,"cmd":"1","name":"آبجوش","count":2}]}
///   برد ← پنل : {"type":"DISPENSE_RESULT","order_id":"ORD-1","status":"OK|PARTIAL|FAILED",
///                "results":[{"rack_number":1,"requested":2,"delivered":2,"status":"OK|MOTOR_JAM","error_code":null}],
///                "addons":[{"addon_id":1,"cmd":"1","count":2,"status":"OK"}]}
/// پوز:
///   پنل ← پوز : {"type":"PAY","order_id":"ORD-1","amount":450000}
///   پوز ← پنل : {"type":"PAY_RESULT","order_id":"ORD-1","status":"APPROVED|DECLINED|CANCELLED","reference":"POS-123","message":""}
///   پنل ← پوز : {"type":"REFUND","order_id":"ORD-1","amount":450000,"reference":"POS-123"}
///   پوز ← پنل : {"type":"REFUND_RESULT","order_id":"ORD-1","status":"REFUNDED|FAILED","message":""}
/// هر دو:
///   پنل ← دستگاه : {"type":"PING"}   |   دستگاه ← پنل : {"type":"PONG","device":"BOARD_SIM"}
class HwProtocol {
  static const String ping = 'PING';
  static const String pong = 'PONG';
  static const String dispense = 'DISPENSE';
  static const String dispenseResult = 'DISPENSE_RESULT';
  static const String pay = 'PAY';
  static const String payResult = 'PAY_RESULT';
  static const String refund = 'REFUND';
  static const String refundResult = 'REFUND_RESULT';
}

/// نتیجه تست اتصال به یک دستگاه
class DeviceCheck {
  final bool ok;
  final String message;
  final int? latencyMs;
  const DeviceCheck(this.ok, this.message, [this.latencyMs]);
}

// ---------------- پرداخت ----------------

enum PaymentStatus { approved, declined, cancelled, timeout, connectionError }

class PaymentResult {
  final PaymentStatus status;
  final String? reference;
  final String message;
  const PaymentResult(this.status, {this.reference, this.message = ''});

  bool get approved => status == PaymentStatus.approved;
}

class RefundResult {
  final bool success;
  final String message;

  /// true = نتیجه بازگشت وجه نامعلوم است (درخواست فرستاده شد ولی پاسخ قطعی نرسید)؛
  /// ممکن است پوز مبلغ را برگردانده باشد، پس نباید بدون بررسی دستی دوباره برگشت زده شود.
  final bool uncertain;

  const RefundResult(this.success, [this.message = '', this.uncertain = false]);
}

// ---------------- تحویل کالا ----------------

enum DispenseStatus { ok, partial, failed, timeout, connectionError }

class RackDispenseResult {
  final int rackNumber;
  final int requested;
  final int delivered;
  final String status;
  final String? errorCode;

  const RackDispenseResult({
    required this.rackNumber,
    required this.requested,
    required this.delivered,
    required this.status,
    this.errorCode,
  });

  bool get complete => delivered >= requested;
}

class DispenseResult {
  final String orderId;
  final DispenseStatus status;
  final List<RackDispenseResult> racks;
  final String message;

  const DispenseResult({
    required this.orderId,
    required this.status,
    this.racks = const [],
    this.message = '',
  });

  /// خطای مهلک (تایم‌اوت یا قطع ارتباط): نتیجه تحویل نامعلوم است
  bool get fatal => status == DispenseStatus.timeout || status == DispenseStatus.connectionError;

  int deliveredFor(int rackNumber) {
    for (final r in racks) {
      if (r.rackNumber == rackNumber) return r.delivered;
    }
    return 0;
  }

  int get totalDelivered => racks.fold(0, (sum, r) => sum + r.delivered);

  /// تبدیل پاسخ خام برد به نتیجه ساختاریافته؛ commands = همان لیستی که به برد فرستاده شده
  factory DispenseResult.fromResponse(
    Map<String, dynamic> response,
    List<Map<String, dynamic>> commands, {
    String fallbackOrderId = '',
  }) {
    final String orderId = (response['order_id'] ?? fallbackOrderId).toString();
    final String raw = (response['status'] ?? '').toString();

    if (raw == 'FATAL_TIMEOUT') {
      return DispenseResult(orderId: orderId, status: DispenseStatus.timeout, message: 'برد در مهلت مقرر پاسخ نداد');
    }
    if (raw == 'CONNECTION_ERROR') {
      return DispenseResult(
        orderId: orderId,
        status: DispenseStatus.connectionError,
        message: (response['message'] ?? 'عدم ارتباط با برد').toString(),
      );
    }

    final Map<int, Map> byRack = {};
    final rawResults = response['results'];
    if (rawResults is List) {
      for (final r in rawResults) {
        if (r is Map && r['rack_number'] is int) {
          byRack[r['rack_number'] as int] = r;
        }
      }
    }

    final List<RackDispenseResult> racks = [];
    int requestedTotal = 0;
    int deliveredTotal = 0;
    for (final c in commands) {
      final int rack = c['rack_number'] as int;
      final int requested = (c['qty'] as int?) ?? 1;
      final Map? r = byRack[rack];

      int delivered;
      String st;
      String? err;
      if (r == null) {
        delivered = raw == 'OK' ? requested : 0;
        st = raw == 'OK' ? 'OK' : 'NO_RESULT';
      } else {
        st = (r['status'] ?? '').toString();
        err = r['error_code']?.toString();
        final d = r['delivered'];
        delivered = d is int ? d : (st == 'OK' ? requested : 0);
      }
      delivered = delivered.clamp(0, requested).toInt();

      requestedTotal += requested;
      deliveredTotal += delivered;
      racks.add(RackDispenseResult(rackNumber: rack, requested: requested, delivered: delivered, status: st, errorCode: err));
    }

    DispenseStatus status;
    if (requestedTotal > 0 && deliveredTotal >= requestedTotal) {
      status = DispenseStatus.ok;
    } else if (deliveredTotal > 0) {
      status = DispenseStatus.partial;
    } else {
      status = DispenseStatus.failed;
    }
    return DispenseResult(orderId: orderId, status: status, racks: racks);
  }
}