import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/database/database_helper.dart';
import 'core/database/default_seeder.dart';
import 'core/bloc/machine/machine_bloc.dart';
import 'features/panel/presentation/screens/selection_screen.dart';

/// برای برگشت کامل به داده پیش‌فرض: یک‌بار true کنید، اجرا کنید، سپس دوباره false کنید.
const bool kResetToDefaultSeed = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;

  // داده پیش‌فرض فقط وقتی دیتابیس خالی است ساخته می‌شود؛ با Hot Restart پاک نمی‌شود
  await DefaultSeeder.run(forceReset: kResetToDefaultSeed);

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