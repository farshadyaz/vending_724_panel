import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/bloc/machine/machine_bloc.dart';
import '../../../../core/bloc/machine/machine_event.dart';
import '../../../../core/database/addon_repository.dart';
import '../../../../core/database/settings_repository.dart';
import '../../../../core/database/vending_repository.dart';
import '../../../../core/utils/order_payload_builder.dart';
import '../widgets/numpad_widget.dart';
import '../widgets/product_card_widget.dart';
import '../widgets/header_widget.dart';
import '../widgets/cart_strip_widget.dart';
import '../widgets/checkout_bar_widget.dart';
import '../widgets/ad_slider_widget.dart';
import '../widgets/guide_widget.dart'; 
import '../widgets/layout_selection_widget.dart';
import '../widgets/admin_pin_dialog.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';

class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> with SingleTickerProviderStateMixin {
  final VendingRepository _repository = VendingRepository();
  final SettingsRepository _settings = SettingsRepository();
  final AddonRepository _addonRepository = AddonRepository();

  // تنظیمات دستگاه
  bool _settingsLoaded = false;
  String _panelMode = SettingsRepository.panelModeKeypad;
  String _adminPin = SettingsRepository.defaultAdminPin;
  int _maxCartCapacity = SettingsRepository.defaultCartCapacity; // ظرفیت سبد (قابل تنظیم)
  int _layoutVersion = 0; // با تغییر آن، چیدمان از دیتابیس دوباره خوانده می‌شود

  String _currentInput = '';
  bool _isInputConfirmed = false;
  Timer? _debounceTimer;
  Map<String, dynamic>? _displayedProduct;
  bool _isSearching = false;
  
  // متغیرهای حالت ادمین (حالت کیپد)
  bool _isAdminMode = false;
  bool _justEnteredAdminMode = false; // پرچم جلوگیری از کلیک ناخواسته پس از رها کردن انگشت
  Timer? _adminHoldTimer;

  // ورود مخفی (حالت چیدمان): ۵ لمس سریع روی هدر
  final List<DateTime> _hiddenTaps = [];
  
  final List<Map<String, dynamic>> _cart = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _adminHoldTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final mode = await _settings.getPanelMode();
    final pin = await _settings.getAdminPin();
    final capacity = await _settings.getCartCapacity();
    if (!mounted) return;
    setState(() {
      _panelMode = mode;
      _adminPin = pin;
      _maxCartCapacity = capacity;
      // اگر ظرفیت کم شده و سبد بیشتر از آن پر است، موارد اضافه از انتهای سبد برداشته می‌شوند
      if (_cart.length > capacity) {
        _cart.removeRange(capacity, _cart.length);
      }
      _settingsLoaded = true;
      _layoutVersion++;
    });
  }

  void _toast(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Vazir', fontSize: 16)),
        backgroundColor: color ?? Colors.red.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------- ورود به پنل مدیریت ----------------

  Future<void> _openAdmin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
    );
    if (!mounted) return;
    // تنظیمات ممکن است در پنل مدیریت تغییر کرده باشد
    setState(() {
      _currentInput = '';
      _isInputConfirmed = false;
      _displayedProduct = null;
    });
    await _loadSettings();
  }

  void _onHeaderTap() {
    final now = DateTime.now();
    _hiddenTaps.add(now);
    _hiddenTaps.removeWhere((t) => now.difference(t) > const Duration(seconds: 3));
    if (_hiddenTaps.length >= 5) {
      _hiddenTaps.clear();
      _openPinDialog();
    }
  }

  Future<void> _openPinDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminPinDialog(expectedPin: _adminPin),
    );
    if (ok == true) {
      debugPrint('LOG [OP-1001]: MAINTENANCE_LOGIN_SUCCESS');
      if (mounted) await _openAdmin();
    }
  }

  // ---------------- حالت کیپد ----------------

  void _onDigitPressed(String digit) {
    // با زدن اولین رقم، قطعاً انگشت از دکمه سبز برداشته شده؛ پرچم دیگر لازم نیست
    _justEnteredAdminMode = false;
    setState(() {
      if (_isAdminMode) {
        if (_currentInput.length < _adminPin.length) {
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
      // هنوز رمز کامل نشده: خطا نده و ورودی را پاک نکن
      if (_currentInput.length < _adminPin.length) {
        _toast('رمز ${_adminPin.length} رقمی را کامل وارد کنید', color: Colors.orange.shade800);
        return;
      }

      if (_currentInput == _adminPin) {
        debugPrint('LOG [OP-1001]: MAINTENANCE_LOGIN_SUCCESS'); 
        _toast('ورود موفق به پنل تکنسین (OP-1001)', color: Colors.green.shade700);
        setState(() {
          _isAdminMode = false;
          _currentInput = '';
        });
        _openAdmin();
      } else {
        debugPrint('LOG: MAINTENANCE_LOGIN_FAILED');
        _toast('رمز عبور نامعتبر');
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

  // ---------------- داده محصول (مشترک بین دو حالت) ----------------

  // تبدیل اطلاعات رک به داده نمایشی کارت محصول (یا پیام خطا)
  Map<String, dynamic> _productFromRack(Map<String, dynamic>? rack) {
    if (rack == null) return {'error': 'ناموجود / رک نامعتبر'};
    if (rack['status'] != 1) return {'error': 'این رک غیرفعال است'};
    if ((rack['stock'] as int) <= 0) return {'error': 'موجودی این رک تمام شده'};
    return {
      'rack_number': rack['rack_number'],
      'physical_address': rack['physical_address'],
      'status': true,
      'name': (rack['product_name'] ?? 'کالا').toString(),
      'price': rack['current_price'] as int,
      'image_path': rack['image_path'],
      'stock': rack['stock'] as int,
    };
  }

  // خواندن رک + محصول + افزودنی‌های همان رک از دیتابیس (یا پیام خطا)
  Future<Map<String, dynamic>> _loadProduct(int rackNumber) async {
    final rack = await _repository.fetchRackForSale(rackNumber);
    final product = _productFromRack(rack);
    if (product.containsKey('error')) return product;
    // اگر حداکثر افزودنی روی صفر باشد (قابلیت خاموش)، افزودنی‌ها به سبد و برد نمی‌روند
    final int maxAddons = await _settings.getMaxAddonsPerRack();
    product['addons'] = maxAddons == 0
        ? <Map<String, dynamic>>[]
        : await _addonRepository.fetchRackAddons(rackNumber);
    return product;
  }

  // حالت کیپد: خواندن اطلاعات واقعی رک و محصول از دیتابیس
  Future<void> _fetchProduct() async {
    if (_currentInput.isEmpty || _currentInput == '00') return;
    final requestedInput = _currentInput;
    setState(() => _isSearching = true);
    
    final rackNumber = int.tryParse(requestedInput) ?? 0;
    final product = await _loadProduct(rackNumber);

    if (!mounted) return;
    // اگر کاربر در این فاصله ورودی را عوض یا پاک کرده، نتیجه قدیمی را نادیده بگیر
    if (requestedInput != _currentInput) return;

    setState(() {
      _isSearching = false;
      _displayedProduct = product;
    });
  }

  // حالت چیدمان: لمس یک رک → باز شدن کارت محصول → افزودن به سبد → بازگشت به چیدمان
  Future<void> _onLayoutRackTap(int rackNumber) async {
    final product = await _loadProduct(rackNumber);
    if (!mounted) return;
    setState(() => _displayedProduct = product);

    final bool? add = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SizedBox(
                    height: 460,
                    child: ProductCardWidget(
                      displayedProduct: _displayedProduct,
                      isSearching: false,
                      cartLength: _cart.length,
                      maxCartCapacity: _maxCartCapacity,
                      onAddToCart: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blueGrey.shade800,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('بازگشت به چیدمان', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (add == true) _addToCart();
    setState(() => _displayedProduct = null);
  }

  void _addToCart() {
    final product = _displayedProduct;
    if (product == null || product['status'] != true) return;

    if (_cart.length >= _maxCartCapacity) {
      _toast('سبد خرید پر است (حداکثر $_maxCartCapacity کالا)', color: Colors.orange.shade800);
      return;
    }

    // تعداد انتخاب‌شده از یک رک نباید از موجودی آن بیشتر شود
    final inCart = _cart.where((item) => item['rack_number'] == product['rack_number']).length;
    if (inCart >= (product['stock'] as int)) {
      _toast('موجودی این رک کافی نیست', color: Colors.orange.shade800);
      return;
    }

    setState(() {
      _cart.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), ...product});
      _currentInput = '';
      _displayedProduct = null;
      _isInputConfirmed = false;
    });
  }

  void _removeFromCart(String tempId) {
    setState(() => _cart.removeWhere((item) => item['id'] == tempId));
  }
  
  void _onCheckout() {
    // لیست سفارش برای برد: کالاهای هر رک + جمع تعداد هر افزودنی در کل سبد
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    final payload = OrderPayloadBuilder.build(orderId, _cart);
    debugPrint('LOG [ORDER_PAYLOAD]: ${jsonEncode(payload)}');

    context.read<MachineBloc>().add(PaymentInitiated());
  }

  // ---------------- رابط ----------------

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _panelMode == SettingsRepository.panelModeLayout ? _buildLayoutMode() : _buildKeypadMode();
  }

  // حالت ۲: چیدمان رک‌ها (هر طبقه یک ردیف تمام‌عرض)
  Widget _buildLayoutMode() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Expanded(
                flex: 10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onHeaderTap, // ورود مخفی تکنسین
                  child: const HeaderWidget(),
                ),
              ),
              const Expanded(
                flex: 10,
                child: AdSliderWidget(),
              ),
              Expanded(
                flex: 50,
                child: LayoutSelectionWidget(
                  key: ValueKey(_layoutVersion),
                  cart: _cart,
                  onRackTap: _onLayoutRackTap,
                ),
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

  // حالت ۱: کیپد و کارت محصول در کنار هم
  Widget _buildKeypadMode() {
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