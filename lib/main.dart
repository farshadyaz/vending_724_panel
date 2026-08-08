import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/database/database_helper.dart';
import 'core/database/vending_repository.dart';
import 'core/bloc/machine/machine_bloc.dart';
import 'features/panel/presentation/screens/selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  
  final repo = VendingRepository();
  await repo.seedDummyData();
  
  runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            // اجباری کردن چیدمان راست‌به‌چپ (RTL) برای کل سیستم
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Vazir', 
          ),
          home: BlocProvider(
            create: (context) => MachineBloc(),
            child: const SelectionScreen(),
          ),
        ),
      );
}