import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/vending_repository.dart';

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

  Future<Map<String, dynamic>> sendDispenseCommand(String orderId, List<Map<String, dynamic>> items) async {
    Socket? socket;
    try {
      socket = await Socket.connect(boardIp, port, timeout: timeout);
      
      final payload = jsonEncode({
        "order_id": orderId,
        "commands": items,
      });

      socket.write(payload);
      
      final responseData = await socket.first.timeout(timeout);
      final responseString = utf8.decode(responseData);
      final jsonResponse = jsonDecode(responseString);

      socket.destroy();
      
      await _processHardwareQuarantine(jsonResponse);
      
      return jsonResponse;

    } on TimeoutException {
      socket?.destroy();
      return {
        "order_id": orderId,
        "status": "FATAL_TIMEOUT",
      };
    } catch (e) {
      socket?.destroy();
      return {
        "order_id": orderId,
        "status": "CONNECTION_ERROR",
        "message": e.toString()
      };
    }
  }
  
  Future<void> _processHardwareQuarantine(Map<String, dynamic> response) async {
    if (response.containsKey('results')) {
      List results = response['results'];
      for (var result in results) {
        if (result['status'] == 'MOTOR_JAM' && result['error_code'] == 'H-1001') {
          int rackNumber = result['rack_number'];
          
          await _repository.quarantineRack(rackNumber);
          final dbCheck = await _repository.checkRackStatus(rackNumber);
          
          debugPrint('CRITICAL ACTION: Rack $rackNumber quarantined in SQLite DB. Current DB Record: $dbCheck');
        }
      }
    }
  }
}