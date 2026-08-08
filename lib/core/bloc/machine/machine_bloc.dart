import 'package:flutter_bloc/flutter_bloc.dart';
import 'machine_event.dart';
import 'machine_state.dart';

class MachineBloc extends Bloc<MachineEvent, MachineState> {
  MachineBloc() : super(MachineIdleState()) {
    
    on<ScreenTouched>((event, emit) {
      if (state is MachineIdleState || state is MachineCompletionState) {
        emit(MachineSelectionState());
      }
    });

    on<PaymentInitiated>((event, emit) {
      if (state is MachineSelectionState) {
        emit(MachinePaymentState());
      }
    });

    on<PaymentSuccess>((event, emit) {
      if (state is MachinePaymentState) {
        emit(MachineDispensingState());
      }
    });

    on<HardwareTimeoutOccurred>((event, emit) {
      if (state is MachineDispensingState) {
        emit(MachineFatalErrorState());
        // طبق سند معماری: انتقال به پایان با پرچم ریفاند کامل پس از خطای مهلک
        emit(const MachineCompletionState(requiresFullRefund: true));
      }
    });

    on<HardwareResponded>((event, emit) {
      if (state is MachineDispensingState) {
        emit(const MachineCompletionState(requiresFullRefund: false));
      }
    });

    on<ResetMachine>((event, emit) {
      emit(MachineIdleState());
    });
  }
}