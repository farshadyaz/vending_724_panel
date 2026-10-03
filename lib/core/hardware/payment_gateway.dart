import 'dart:async';
import 'dart:io';
import 'hardware_models.dart';
import 'ndjson_client.dart';

/// یک پرداخت در حال انتظار؛ با cancel() می‌توان آن را لغو کرد.
class PaymentSession {
  final Future<PaymentResult> result;
  final void Function() cancel;
  const PaymentSession(this.result, this.cancel);
}

/// رابط پوز: امروز شبیه‌ساز (TCP) یا Mock داخلی، فردا پوز واقعی با پیاده‌سازی جدید همین رابط.
abstract class PaymentGateway {
  PaymentSession startPayment({required String orderId, required int amount});
  Future<DeviceCheck> ping();
}

/// ارتباط TCP با پوز (یا شبیه‌ساز پوز)
class TcpPosGateway implements PaymentGateway {
  final String host;
  final int port;
  final Duration payTimeout; // مهلت پرداخت مشتری

  const TcpPosGateway({
    required this.host,
    required this.port,
    this.payTimeout = const Duration(seconds: 90),
  });

  @override
  PaymentSession startPayment({required String orderId, required int amount}) {
    final call = NdjsonCall(
      host: host,
      port: port,
      payload: {'type': HwProtocol.pay, 'order_id': orderId, 'amount': amount},
      responseTimeout: payTimeout,
    );
    return PaymentSession(_awaitPayment(call), call.cancel);
  }

  Future<PaymentResult> _awaitPayment(NdjsonCall call) async {
    try {
      final response = await call.future;
      final status = (response['status'] ?? '').toString();
      final reference = response['reference']?.toString();
      final message = (response['message'] ?? '').toString();
      if (status == 'APPROVED') {
        return PaymentResult(PaymentStatus.approved, reference: reference, message: message);
      }
      if (status == 'CANCELLED') {
        return PaymentResult(PaymentStatus.cancelled, message: message.isEmpty ? 'پرداخت لغو شد' : message);
      }
      return PaymentResult(PaymentStatus.declined, message: message.isEmpty ? 'پرداخت رد شد' : message);
    } on CallCancelledException {
      return const PaymentResult(PaymentStatus.cancelled, message: 'پرداخت توسط مشتری لغو شد');
    } on TimeoutException {
      return const PaymentResult(PaymentStatus.timeout, message: 'پاسخی از پوز دریافت نشد');
    } on SocketException catch (e) {
      return PaymentResult(PaymentStatus.connectionError, message: 'عدم ارتباط با پوز: ${e.message}');
    } catch (e) {
      return PaymentResult(PaymentStatus.connectionError, message: 'خطای ارتباط با پوز: $e');
    }
  }

  @override
  Future<DeviceCheck> ping() => pingDevice(host, port);
}

/// پوز آزمایشی داخلی: بدون شبکه، پس از ۱ ثانیه همیشه تأیید می‌کند.
class MockPosGateway implements PaymentGateway {
  const MockPosGateway();

  @override
  PaymentSession startPayment({required String orderId, required int amount}) {
    final completer = Completer<PaymentResult>();
    final timer = Timer(const Duration(seconds: 1), () {
      if (!completer.isCompleted) {
        completer.complete(PaymentResult(
          PaymentStatus.approved,
          reference: 'MOCK-${DateTime.now().millisecondsSinceEpoch % 1000000}',
          message: 'تأیید پوز آزمایشی',
        ));
      }
    });
    return PaymentSession(completer.future, () {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.complete(const PaymentResult(PaymentStatus.cancelled, message: 'پرداخت توسط مشتری لغو شد'));
      }
    });
  }

  @override
  Future<DeviceCheck> ping() async => const DeviceCheck(true, 'شبیه‌ساز داخلی پوز', 0);
}