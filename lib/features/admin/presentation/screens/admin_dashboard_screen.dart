import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoggedIn = false;
  String _selectedRole = 'operator';
  String _enteredPin = '';

  final Map<String, String> _rolePins = {
    'operator': '111111',
    'owner': '222222',
    'technician': '333333',
  };

  void _onDigitPressed(String digit) {
    setState(() {
      if (_enteredPin.length < 6) {
        _enteredPin += digit;
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  void _handleSecondaryLogin() {
    if (_enteredPin == _rolePins[_selectedRole]) {
      setState(() {
        _isLoggedIn = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ورود موفق با نقش: ${_getRoleName(_selectedRole)}', style: const TextStyle(fontFamily: 'Vazir', fontSize: 16)),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز عبور ۶ رقمی نامعتبر است', style: TextStyle(fontFamily: 'Vazir', fontSize: 16)),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _enteredPin = '';
      });
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'operator': return 'اپراتور';
      case 'owner': return 'مالک';
      case 'technician': return 'تیم فنی و تولید';
      default: return '';
    }
  }

  void _openModulePopup(BuildContext context, String moduleTitle) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.settings_suggest, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  moduleTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 200,
            child: Center(
              child: Text(
                'محیط تنظیمات مربوط به «$moduleTitle»\n(به زودی در این بخش پیاده‌سازی می‌شود)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blueGrey.shade800,
        title: Text(
          _isLoggedIn ? 'پنل مدیریت ادمین (${_getRoleName(_selectedRole)})' : 'احراز هویت دوم (سطوح دسترسی)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'تغییر کاربر',
              onPressed: () => setState(() {
                _isLoggedIn = false;
                _enteredPin = '';
              }),
            ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoggedIn ? _buildDashboardContent() : _buildOnScreenLoginForm(),
      ),
    );
  }

  Widget _buildOnScreenLoginForm() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 48, color: Colors.blueGrey),
              const SizedBox(height: 12),
              const Text(
                'انتخاب سطح دسترسی و ورود پین ۶ رقمی',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'نقش کاربر',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'operator', child: Text('اپراتور (رمز: 111111)')),
                  DropdownMenuItem(value: 'owner', child: Text('مالک (رمز: 222222)')),
                  DropdownMenuItem(value: 'technician', child: Text('تیم فنی و تولید (رمز: 333333)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                      _enteredPin = '';
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  bool isFilled = _enteredPin.length > index;
                  return Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isFilled ? Colors.blue : Colors.grey.shade300, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        isFilled ? '*' : '',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              // استفاده از shrinkWrap به جای SizedBox با ارتفاع ثابت برای جلوگیری از بیرون‌زدگی
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 1; i <= 9; i++) _buildKey(i.toString()),
                  _buildActionKey('تایید', Colors.green.shade600, _handleSecondaryLogin),
                  _buildKey('0'),
                  _buildActionKey('حذف', Colors.red.shade400, _onBackspacePressed),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String text) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _onDigitPressed(text),
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    final List<Map<String, dynamic>> allCards = [
      {'id': 1, 'title': 'لیست محصولات', 'icon': Icons.list_alt_outlined, 'roles': ['operator', 'owner', 'technician']},
      {'id': 2, 'title': 'افزودن محصول', 'icon': Icons.add_box_outlined, 'roles': ['operator', 'owner', 'technician']},
      {'id': 3, 'title': 'تنظیمات لایوت (چیدمان) رک', 'icon': Icons.grid_view_outlined, 'roles': ['operator', 'owner', 'technician']},
      {'id': 4, 'title': 'تنظیمات شبکه / سرور', 'icon': Icons.lan_outlined, 'roles': ['owner', 'technician']},
      {'id': 5, 'title': 'معرفی دستگاه پوز', 'icon': Icons.point_of_sale_outlined, 'roles': ['owner', 'technician']},
      {'id': 6, 'title': 'بخش تبلیغات', 'icon': Icons.campaign_outlined, 'roles': ['owner', 'technician']},
      {'id': 7, 'title': 'آمار فروش', 'icon': Icons.bar_chart_outlined, 'roles': ['owner', 'technician']},
      {'id': 8, 'title': 'لاگ‌های سیستم پنل', 'icon': Icons.text_snippet_outlined, 'roles': ['technician']},
      {'id': 9, 'title': 'خطا / لاگ برد الکترونیکی', 'icon': Icons.bug_report_outlined, 'roles': ['technician']},
      {'id': 10, 'title': 'پنل تنظیمات اس‌ام‌اس', 'icon': Icons.sms_outlined, 'roles': ['owner', 'technician']},
      {'id': 11, 'title': 'مدیریت کاربران', 'icon': Icons.manage_accounts_outlined, 'roles': ['owner', 'technician']}, // گزینه جدید مدیریت کاربران
    ];

    final permittedCards = allCards.where((card) => (card['roles'] as List).contains(_selectedRole)).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: permittedCards.length,
              itemBuilder: (context, index) {
                final card = permittedCards[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Icon(card['icon'], color: Colors.blueGrey.shade700, size: 26),
                    title: Text(
                      card['title'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => _openModulePopup(context, card['title']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}