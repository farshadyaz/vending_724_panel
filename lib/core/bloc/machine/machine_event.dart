import 'package:equatable/equatable.dart';

abstract class MachineEvent extends Equatable {
  const MachineEvent();

  @override
  List<Object> get props => [];
}

class ScreenTouched extends MachineEvent {}
class PaymentInitiated extends MachineEvent {}
class PaymentSuccess extends MachineEvent {}
class HardwareTimeoutOccurred extends MachineEvent {}
class HardwareResponded extends MachineEvent {}
class ResetMachine extends MachineEvent {}