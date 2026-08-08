import 'package:equatable/equatable.dart';

abstract class MachineState extends Equatable {
  const MachineState();
  
  @override
  List<Object> get props => [];
}

class MachineIdleState extends MachineState {}

class MachineSelectionState extends MachineState {}

class MachinePaymentState extends MachineState {}

class MachineDispensingState extends MachineState {}

class MachineFatalErrorState extends MachineState {}

class MachineCompletionState extends MachineState {
  final bool requiresFullRefund;
  
  const MachineCompletionState({this.requiresFullRefund = false});

  @override
  List<Object> get props => [requiresFullRefund];
}