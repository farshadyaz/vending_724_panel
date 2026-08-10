import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/bloc/machine/machine_bloc.dart';
import '../../../../core/bloc/machine/machine_event.dart';
import '../../../../core/database/vending_repository.dart';
import '../widgets/numpad_widget.dart';
import '../widgets/product_card_widget.dart';
import '../widgets/header_widget.dart';
import '../widgets/cart_strip_widget.dart';
import '../widgets/checkout_bar_widget.dart';
import '../widgets/ad_slider_widget.dart';
import '../widgets/guide_widget.dart'; 
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';

class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> with SingleTickerProviderStateMixin {
  final VendingRepository _repository = VendingRepository();
  
  String _currentInput = '';
  bool _isInputConfirmed = false;
  Timer? _debounceTimer;
  Map<String, dynamic>? _displayedProduct;
  bool _isSearching = false;
  
  // متغیرهای حالت ادمین
  bool _isAdminMode = false;
  bool _justEnteredAdminMode = false; // پرچم جلوگیری از کلیک ناخواسته پس از رها کردن انگشت
  Timer? _adminHoldTimer;
  final String _correctAdminPin = '4848';
  
  final List<Map<String, dynamic>> _cart = [];
  final int _maxCartCapacity = 5;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _adminHoldTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    setState(() {
      if (_isAdminMode) {
        if (_currentInput.length < 4) {
          _currentInput += digit;
        }
      } else {
        if (_currentInput.length >= 2) return;
        _currentInput += digit;
        _displayedProduct = null;
        _isInputConfirmed = false;
        
        _debounceTimer?.cancel();

        if (_currentInput.length == 2) {
          _pulseController.stop();
          _pulseController.reset();
          _isInputConfirmed = true;
          _fetchProduct();
        } else {
          _pulseController.repeat(reverse: true);
          _debounceTimer = Timer(const Duration(milliseconds: 2500), () {
            _pulseController.stop();
            _pulseController.reset();
            setState(() => _isInputConfirmed = true);
            _fetchProduct();
          });
        }
      }
    });
  }

  void _onGreenTapDown(TapDownDetails details) {
    if (_currentInput == '00' && !_isAdminMode) {
      _adminHoldTimer = Timer(const Duration(seconds: 3), () {
        setState(() {
          _isAdminMode = true;
          _justEnteredAdminMode = true; // فعال‌سازی پرچم برای نادیده گرفتن رویداد Tap هنگام برداشتن انگشت
          _currentInput = ''; 
          _displayedProduct = null;
        });
        _debounceTimer?.cancel();
        _pulseController.stop();
        _pulseController.reset();
      });
    }
  }

  void _onGreenTapUpCancel() {
    _adminHoldTimer?.cancel();
  }

  void _onGreenTap() {
    _adminHoldTimer?.cancel();

    // اگر تازه از حالت ۳ ثانیه نگه داشتن خارج شده‌ایم، این کلیک (که ناشی از برداشتن انگشت است) را نادیده بگیر
    if (_justEnteredAdminMode) {
      _justEnteredAdminMode = false;
      return;
    }

    if (_isAdminMode) {
      if (_currentInput == _correctAdminPin) {
        debugPrint('LOG [OP-1001]: MAINTENANCE_LOGIN_SUCCESS'); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ورود موفق به پنل تکنسین (OP-1001)', style: TextStyle(fontFamily: 'Vazir', fontSize: 16)),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _isAdminMode = false;
          _currentInput = '';
        });
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        debugPrint('LOG: MAINTENANCE_LOGIN_FAILED');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('رمز عبور نامعتبر', style: TextStyle(fontFamily: 'Vazir', fontSize: 16)),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _currentInput = '';
        });
      }
    } else {
      if (_currentInput.isNotEmpty && !_isInputConfirmed) {
        _debounceTimer?.cancel();
        _pulseController.stop();
        _pulseController.reset();
        setState(() => _isInputConfirmed = true);
        _fetchProduct();
      }
    }
  }

  void _onRedButtonPressed() {
    _debounceTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    
    setState(() {
      if (_isAdminMode) {
        if (_currentInput.isEmpty) {
          _isAdminMode = false; 
        } else {
          _currentInput = _currentInput.substring(0, _currentInput.length - 1);
        }
      } else {
        _currentInput = '';
        _displayedProduct = null;
        _isInputConfirmed = false;
      }
    });
  }

  Future<void> _fetchProduct() async {
    if (_currentInput.isEmpty || _currentInput == '00') return;
    setState(() => _isSearching = true);
    
    final rackNumber = int.tryParse(_currentInput) ?? 0;
    final rackData = await _repository.checkRackStatus(rackNumber);

    setState(() {
      _isSearching = false;
      if (rackData.isNotEmpty) {
        final rack = rackData.first;
        _displayedProduct = {
          'rack_number': rack['rack_number'],
          'status': rack['status'] == 1,
          'name': 'کالای تستی رک ${rack['rack_number']}',
          'price': 25000,
          'image': Icons.fastfood,
        };
      } else {
        _displayedProduct = {'error': 'ناموجود / رک نامعتبر'};
      }
    });
  }

  void _addToCart() {
    if (_displayedProduct != null && _displayedProduct!['status'] == true && _cart.length < _maxCartCapacity) {
      setState(() {
        _cart.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), ..._displayedProduct!});
        _currentInput = '';
        _displayedProduct = null;
        _isInputConfirmed = false;
      });
    }
  }

  void _removeFromCart(String tempId) {
    setState(() => _cart.removeWhere((item) => item['id'] == tempId));
  }
  
  void _onCheckout() {
    context.read<MachineBloc>().add(PaymentInitiated());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              const Expanded(
                flex: 10,
                child: HeaderWidget(),
              ),
              const Expanded(
                flex: 10,
                child: AdSliderWidget(),
              ),
              Expanded(
                flex: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch, 
                    children: [
                      Expanded(
                        flex: 1, 
                        child: NumpadWidget(
                          currentInput: _currentInput,
                          isInputConfirmed: _isInputConfirmed,
                          isAdminMode: _isAdminMode,
                          pulseAnimation: _pulseAnimation,
                          onDigitPressed: _onDigitPressed,
                          onGreenTap: _onGreenTap,
                          onGreenTapDown: _onGreenTapDown,
                          onGreenTapUpCancel: _onGreenTapUpCancel,
                          onRedPressed: _onRedButtonPressed,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1, 
                        child: ProductCardWidget(
                          displayedProduct: _displayedProduct,
                          isSearching: _isSearching,
                          cartLength: _cart.length,
                          maxCartCapacity: _maxCartCapacity,
                          onAddToCart: _addToCart,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Expanded(
                flex: 15,
                child: GuideWidget(),
              ),
              Expanded(
                flex: 15,
                child: CartStripWidget(
                  cart: _cart,
                  maxCartCapacity: _maxCartCapacity,
                  onRemoveFromCart: _removeFromCart,
                ),
              ),
              Expanded(
                flex: 10,
                child: CheckoutBarWidget(
                  cart: _cart,
                  onCheckout: _cart.isEmpty ? null : _onCheckout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}