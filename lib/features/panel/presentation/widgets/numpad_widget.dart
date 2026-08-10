import 'package:flutter/material.dart';

class NumpadWidget extends StatelessWidget {
  final String currentInput;
  final bool isInputConfirmed;
  final bool isAdminMode;
  final Animation<double> pulseAnimation;
  final Function(String) onDigitPressed;
  final VoidCallback onGreenTap;
  final GestureTapDownCallback onGreenTapDown;
  final VoidCallback onGreenTapUpCancel;
  final VoidCallback onRedPressed;

  const NumpadWidget({
    super.key,
    required this.currentInput,
    required this.isInputConfirmed,
    required this.isAdminMode,
    required this.pulseAnimation,
    required this.onDigitPressed,
    required this.onGreenTap,
    required this.onGreenTapDown,
    required this.onGreenTapUpCancel,
    required this.onRedPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        // پدینگ افقی بیشتر شد تا دکمه‌ها از عرض خیلی کشیده نشوند
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: isAdminMode 
                    ? _buildAdminInputBoxes() 
                    : _buildNormalInputBoxes(),
              ),
            ),
            const SizedBox(height: 16), // فاصله کمی کمتر شد
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8, // فاصله عمودی کمتر شد
                crossAxisSpacing: 8, // فاصله افقی کمتر شد
                childAspectRatio: 1.4, // دکمه‌ها مستطیلی‌تر و جمع‌وجورتر شدند
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 1; i <= 9; i++) _buildKey(i.toString()),
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: pulseAnimation.value,
                      child: _buildActionKey(
                        content: const Text('تایید', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        color: Colors.green.shade600,
                        onTap: onGreenTap,
                        onTapDown: onGreenTapDown,
                        onTapUpCancel: onGreenTapUpCancel,
                      ),
                    ),
                  ),
                  _buildKey('0'),
                  _buildActionKey(
                    content: const Icon(Icons.backspace_outlined, color: Colors.white, size: 22), // سایز آیکون بهینه‌تر شد
                    color: Colors.red.shade400,
                    onTap: onRedPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAdminInputBoxes() {
    return [
      const Icon(Icons.lock_outline, color: Colors.blueGrey, size: 24),
      const SizedBox(width: 8),
      ...List.generate(4, (index) {
        bool isFilled = currentInput.length > index;
        return _buildInputBox(
          char: isFilled ? '*' : '',
          isFilled: isFilled,
          isConfirmed: false,
          isHidden: false,
          size: 32, // سایز مینیمال‌تر
          fontSize: 20, 
        );
      })
    ];
  }

  List<Widget> _buildNormalInputBoxes() {
    return [
      _buildInputBox(
        char: currentInput.isNotEmpty ? currentInput[0] : '',
        isFilled: currentInput.isNotEmpty,
        isConfirmed: isInputConfirmed,
        isHidden: false,
        size: 40, // سایز مینیمال‌تر
        fontSize: 20, 
      ),
      _buildInputBox(
        char: currentInput.length > 1 ? currentInput[1] : '',
        isFilled: currentInput.length > 1,
        isConfirmed: isInputConfirmed,
        isHidden: isInputConfirmed && currentInput.length == 1,
        size: 40, 
        fontSize: 20, 
      ),
    ];
  }

  Widget _buildInputBox({
    required String char, 
    required bool isFilled, 
    required bool isConfirmed, 
    required bool isHidden,
    required double size,
    required double fontSize,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isHidden ? 0 : size,
      height: size,
      margin: EdgeInsets.symmetric(horizontal: isHidden ? 0 : 4), // مارجین باکس‌ها کمی کمتر شد
      decoration: BoxDecoration(
        color: isHidden ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(10), // گردی ملایم‌تر
        border: Border.all(
          color: isHidden 
              ? Colors.transparent 
              : (isConfirmed ? Colors.green.shade500 : (isFilled ? Colors.blue.shade400 : Colors.grey.shade300)),
          width: isHidden ? 0.0 : (isFilled || isConfirmed ? 2.0 : 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: (isConfirmed && !isHidden) 
                ? Colors.green.withValues(alpha: 0.2) 
                : Colors.transparent,
            blurRadius: (isConfirmed && !isHidden) ? 8 : 0,
          )
        ],
      ),
      child: Center(
        child: Text(
          char,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: isHidden ? Colors.transparent : Colors.black87,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String text) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 0.5,
      child: InkWell(
        onTap: () => onDigitPressed(text),
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), // فونت مینیمال‌تر
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required Widget content, 
    required Color color, 
    required VoidCallback onTap,
    GestureTapDownCallback? onTapDown,
    VoidCallback? onTapUpCancel,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      elevation: 0.5,
      child: InkWell(
        onTap: onTap,
        onTapDown: onTapDown,
        onTapUp: (_) => onTapUpCancel?.call(),
        onTapCancel: onTapUpCancel,
        borderRadius: BorderRadius.circular(10),
        child: Center(child: content),
      ),
    );
  }
}