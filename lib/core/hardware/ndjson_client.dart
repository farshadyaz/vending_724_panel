import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'hardware_models.dart';

/// وقتی تماس توسط خود برنامه لغو شود (مثلاً مشتری پرداخت را لغو کرد)
class CallCancelledException implements Exception {
  const CallCancelledException();

  @override
  String toString() => 'تماس لغو شد';
}

/// یک درخواست TCP: ارسال یک پیام JSON (یک خط) و دریافت یک پاسخ JSON (یک خط).
/// با cancel() می‌توان تماس در حال انتظار را قطع کرد.
class NdjsonCall {
  final String host;
  final int port;
  final Map<String, dynamic> payload;
  final Duration connectTimeout;
  final Duration responseTimeout;

  Socket? _socket;
  bool _cancelled = false;
  bool _requestSent = false;
  late final Future<Map<String, dynamic>> future;

  /// true = درخواست (حتی ناقص) روی اتصال نوشته شده؛ از این لحظه به بعد دستگاه ممکن است آن را اجرا کرده باشد.
  /// false = اتصال برقرار نشد و مطمئنیم دستگاه چیزی دریافت نکرده است.
  bool get requestSent => _requestSent;

  NdjsonCall({
    required this.host,
    required this.port,
    required this.payload,
    this.connectTimeout = const Duration(seconds: 5),
    this.responseTimeout = const Duration(seconds: 10),
  }) {
    future = _run();
  }

  /// نسخه ساده: ارسال و انتظار برای پاسخ
  static Future<Map<String, dynamic>> request({
    required String host,
    required int port,
    required Map<String, dynamic> payload,
    Duration connectTimeout = const Duration(seconds: 5),
    Duration responseTimeout = const Duration(seconds: 10),
  }) {
    return NdjsonCall(
      host: host,
      port: port,
      payload: payload,
      connectTimeout: connectTimeout,
      responseTimeout: responseTimeout,
    ).future;
  }

  Future<Map<String, dynamic>> _run() async {
    try {
      final socket = await Socket.connect(host, port, timeout: connectTimeout);
      _socket = socket;
      if (_cancelled) {
        socket.destroy();
        throw const CallCancelledException();
      }

      _requestSent = true;
      socket.write('${jsonEncode(payload)}\n');
      await socket.flush();

      final String line;
      try {
        line = await socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(responseTimeout);
      } on StateError {
        // دستگاه اتصال را بدون ارسال پاسخ بسته است
        throw const SocketException('دستگاه اتصال را بدون پاسخ بست');
      }

      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const FormatException('پاسخ دستگاه یک آبجکت JSON نیست');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (_cancelled) throw const CallCancelledException();
      rethrow;
    } finally {
      _socket?.destroy();
    }
  }

  /// قطع تماس در حال انتظار؛ future با CallCancelledException تمام می‌شود
  void cancel() {
    _cancelled = true;
    _socket?.destroy();
  }
}

/// تست اتصال به یک دستگاه (برد یا پوز) با پیام PING؛ زمان رفت‌وبرگشت را هم برمی‌گرداند
Future<DeviceCheck> pingDevice(String host, int port) async {
  final sw = Stopwatch()..start();
  try {
    final response = await NdjsonCall.request(
      host: host,
      port: port,
      payload: {'type': HwProtocol.ping},
      connectTimeout: const Duration(seconds: 3),
      responseTimeout: const Duration(seconds: 3),
    );
    sw.stop();
    if (response['type'] == HwProtocol.pong) {
      final device = (response['device'] ?? 'دستگاه').toString();
      return DeviceCheck(true, 'متصل ($device)', sw.elapsedMilliseconds);
    }
    return const DeviceCheck(false, 'پاسخ نامعتبر از دستگاه');
  } on TimeoutException {
    return const DeviceCheck(false, 'دستگاه پاسخ نداد (تایم‌اوت)');
  } on SocketException catch (e) {
    return DeviceCheck(false, 'عدم ارتباط: ${e.message}');
  } catch (e) {
    return DeviceCheck(false, 'خطا: $e');
  }
}