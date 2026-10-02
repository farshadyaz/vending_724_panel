import '../network/hardware_client.dart';
import 'hardware_models.dart';
import 'ndjson_client.dart';

/// رابط برد الکترونیکی: امروز شبیه‌ساز (TCP) یا Mock داخلی، فردا برد واقعی با پیاده‌سازی جدید همین رابط.
abstract class BoardGateway {
  /// commands = کالاهای هر رک ({rack_number, physical_address, qty})
  /// addons   = جمع تعداد هر افزودنی ({addon_id, cmd, name, count})
  Future<DispenseResult> dispense({
    required String orderId,
    required List<Map<String, dynamic>> commands,
    required List<Map<String, dynamic>> addons,
  });

  Future<DeviceCheck> ping();
}

/// ارتباط TCP با برد (یا شبیه‌ساز برد)
class TcpBoardGateway implements BoardGateway {
  final String host;
  final int port;
  final Duration timeout;
  final HardwareClient _client;

  TcpBoardGateway({
    required this.host,
    required this.port,
    this.timeout = const Duration(seconds: 20),
  }) : _client = HardwareClient(boardIp: host, port: port, timeout: timeout);

  @override
  Future<DispenseResult> dispense({
    required String orderId,
    required List<Map<String, dynamic>> commands,
    required List<Map<String, dynamic>> addons,
  }) async {
    final response = await _client.sendDispenseCommand(orderId, commands, addons: addons);
    return DispenseResult.fromResponse(response, commands, fallbackOrderId: orderId);
  }

  @override
  Future<DeviceCheck> ping() => pingDevice(host, port);
}

/// برد آزمایشی داخلی: بدون شبکه، پس از ۱.۵ ثانیه همه کالاها را تحویل‌شده اعلام می‌کند.
class MockBoardGateway implements BoardGateway {
  const MockBoardGateway();

  @override
  Future<DispenseResult> dispense({
    required String orderId,
    required List<Map<String, dynamic>> commands,
    required List<Map<String, dynamic>> addons,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    return DispenseResult.fromResponse(
      {'order_id': orderId, 'status': 'OK'},
      commands,
      fallbackOrderId: orderId,
    );
  }

  @override
  Future<DeviceCheck> ping() async => const DeviceCheck(true, 'شبیه‌ساز داخلی برد', 0);
}