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
  /// true = تحویل کالا نامعلوم ماند (تایم‌اوت/قطع ارتباط با برد)؛ مشتری باید با اپراتور تماس بگیرد
  final bool requiresOperatorFollowUp;
  
  const MachineCompletionState({this.requiresOperatorFollowUp = false});

  @override
  List<Object> get props => [requiresOperatorFollowUp];
}