import 'package:flutter/material.dart';
import '../../../../core/widgets/pin_pad.dart';

/// پنجره ورود رمز اولیه تکنسین (برای ورود مخفی در حالت چیدمان)
/// با بستن موفق، مقدار true برمی‌گرداند.
class AdminPinDialog extends StatefulWidget {
  final String expectedPin;

  const AdminPinDialog({super.key, required this.expectedPin});

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  static const Color _ink = Color(0xFF2B3A47);

  String _value = '';
  bool _error = false;
  int _fails = 0;
  DateTime? _lockedUntil;

  bool get _locked => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  void _digit(String d) {
    if (_locked || _error) return;
    if (_value.length >= widget.expectedPin.length) return;
    setState(() => _value += d);
    if (_value.length == widget.expectedPin.length) _check();
  }

  void _backspace() {
    if (_locked || _error || _value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  Future<void> _check() async {
    if (_value == widget.expectedPin) {
      Navigator.pop(context, true);
      return;
    }
    _fails++;
    if (_fails >= 5) {
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _fails = 0;
    }
    setState(() => _error = true);
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _value = '';
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool locked = _locked;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 34, color: Colors.blueGrey.shade600),
              const SizedBox(height: 8),
              const Text('رمز ورود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
              const SizedBox(height: 16),
              PinPad(
                value: _value,
                length: widget.expectedPin.length,
                error: _error,
                onDigit: _digit,
                onBackspace: _backspace,
                onClear: () {
                  if (!_locked && !_error) setState(() => _value = '');
                },
              ),
              SizedBox(
                height: 28,
                child: Center(
                  child: Text(
                    locked
                        ? 'به‌دلیل تلاش‌های ناموفق، ۳۰ ثانیه صبر کنید'
                        : (_error ? 'رمز نادرست است' : ''),
                    style: TextStyle(color: Colors.red.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف', style: TextStyle(color: _ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}