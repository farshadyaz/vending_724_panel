import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/vending_repository.dart';
import '../hardware/hardware_models.dart';
import '../hardware/ndjson_client.dart';

/// ارتباط TCP با برد الکترونیکی (پروتکل JSON تک‌خطی؛ ببینید hardware_models.dart)
class HardwareClient {
  final String boardIp;
  final int port;
  final Duration timeout;
  final VendingRepository _repository = VendingRepository();

  HardwareClient({
    this.boardIp = '127.0.0.1', 
    this.port = 8080,
    this.timeout = const Duration(seconds: 10),
  });

  /// items = کالاهای هر رک (commands)
  /// addons = جمع تعداد هر افزودنی در کل سفارش (مثلاً [{addon_id: 1, cmd: '1', count: 2}])
  Future<Map<String, dynamic>> sendDispenseCommand(
    String orderId,
    List<Map<String, dynamic>> items, {
    List<Map<String, dynamic>> addons = const [],
  }) async {
    try {
      final response = await NdjsonCall.request(
        host: boardIp,
        port: port,
        payload: {
          'type': HwProtocol.dispense,
          'order_id': orderId,
          'commands': items,
          'addons': addons,
        },
        responseTimeout: timeout,
      );

      // خطای دیتابیس هنگام قرنطینه نباید پاسخ واقعی برد را از بین ببرد
      try {
        await _processHardwareQuarantine(response);
      } catch (e) {
        debugPrint('WARNING: quarantine bookkeeping failed: $e');
      }

      return response;
    } on TimeoutException {
      return {
        "order_id": orderId,
        "status": "FATAL_TIMEOUT",
      };
    } catch (e) {
      return {
        "order_id": orderId,
        "status": "CONNECTION_ERROR",
        "message": e.toString()
      };
    }
  }
  
  Future<void> _processHardwareQuarantine(Map<String, dynamic> response) async {
    final results = response['results'];
    if (results is! List) return;
    for (final result in results) {
      if (result is Map &&
          result['status'] == 'MOTOR_JAM' &&
          result['error_code'] == 'H-1001' &&
          result['rack_number'] is int) {
        final int rackNumber = result['rack_number'] as int;

        await _repository.quarantineRack(rackNumber);
        final dbCheck = await _repository.checkRackStatus(rackNumber);

        debugPrint('CRITICAL ACTION: Rack $rackNumber quarantined in SQLite DB. Current DB Record: $dbCheck');
      }
    }
  }
}