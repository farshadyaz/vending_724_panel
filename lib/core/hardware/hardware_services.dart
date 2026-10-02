import '../database/settings_repository.dart';
import 'board_gateway.dart';
import 'payment_gateway.dart';

/// نقطه واحد دسترسی به برد و پوز؛ بر اساس «تنظیمات شبکه / سرور» ساخته می‌شود.
/// ماژول‌های واقعی برد/پوز در آینده فقط اینجا جایگزین می‌شوند.
class HardwareServices {
  final PaymentGateway payment;
  final BoardGateway board;
  final bool isMock;

  const HardwareServices({required this.payment, required this.board, required this.isMock});

  static Future<HardwareServices> load() async {
    final settings = SettingsRepository();
    final mode = await settings.getHardwareMode();

    if (mode == SettingsRepository.hardwareModeMock) {
      return const HardwareServices(
        payment: MockPosGateway(),
        board: MockBoardGateway(),
        isMock: true,
      );
    }

    return HardwareServices(
      payment: TcpPosGateway(
        host: await settings.getPosIp(),
        port: await settings.getPosPort(),
      ),
      board: TcpBoardGateway(
        host: await settings.getBoardIp(),
        port: await settings.getBoardPort(),
      ),
      isMock: false,
    );
  }
}
