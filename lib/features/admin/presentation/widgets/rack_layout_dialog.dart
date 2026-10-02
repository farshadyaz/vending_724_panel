import 'package:flutter/material.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/database/vending_repository.dart';
import 'product_thumb.dart';
import 'rack_editor_dialog.dart';

class RackLayoutDialog extends StatefulWidget {
  const RackLayoutDialog({super.key});

  @override
  State<RackLayoutDialog> createState() => _RackLayoutDialogState();
}

class _RackLayoutDialogState extends State<RackLayoutDialog> {
  static const int _lowStockThreshold = 3;
  static const int _rackCapacity = 10; // ظرفیت فرضی هر رک برای نوار سطح موجودی

  final VendingRepository _repo = VendingRepository();
  List<Map<String, dynamic>> _layout = [];
  Map<int, Map<String, dynamic>> _racks = {};
  List<Map<String, dynamic>> _products = [];
  Map<int, String> _imageById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final layout = await _repo.fetchLayout();
    final racks = await _repo.fetchRacksWithProducts();
    final products = await _repo.fetchActiveProducts();
    if (!mounted) return;
    setState(() {
      _layout = layout;
      _racks = {for (var r in racks) r['rack_number'] as int: r};
      _products = products;
      _imageById = {for (var p in products) p['id'] as int: p['image_path'] as String};
      _loading = false;
    });
  }

  Future<void> _openRackEditor(int rackNumber, int shelf, int column) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RackEditorDialog(
        rackNumber: rackNumber,
        physicalAddress: shelf * 1000 + column,
        existing: _racks[rackNumber],
        products: _products,
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _loading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    int totalSlots = 0;
    for (final s in _layout) {
      totalSlots += s['columns_count'] as int;
    }
    int active = 0, low = 0, soldOut = 0, quarantined = 0;
    for (final r in _racks.values) {
      final stock = r['stock'] as int;
      if (r['status'] == 0) {
        quarantined++;
      } else if (stock == 0) {
        soldOut++;
      } else if (stock <= _lowStockThreshold) {
        low++;
      } else {
        active++;
      }
    }
    final empty = totalSlots - _racks.length;

    int baseRack = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view_outlined, color: Colors.blueGrey),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('لایوت رک‌ها (محصول‌گذاری)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'برای تنظیم محصول، قیمت و موجودی روی هر رک بزنید.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _summaryChip(Colors.green.shade600, 'فعال', active),
            _summaryChip(Colors.orange.shade700, 'کم‌موجودی', low),
            _summaryChip(Colors.red.shade600, 'تمام‌شده', soldOut),
            _summaryChip(Colors.red.shade900, 'غیرفعال', quarantined),
            _summaryChip(Colors.grey.shade600, 'خالی', empty < 0 ? 0 : empty),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _layout.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'ساختار دستگاه هنوز تعریف نشده است.\nابتدا از «تنظیمات دستگاه» تعداد طبقات و رک‌ها را مشخص کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EDF1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueGrey.shade300, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _layout.map((shelfRow) {
                          final shelf = shelfRow['shelf_number'] as int;
                          final cols = shelfRow['columns_count'] as int;
                          final start = baseRack;
                          baseRack += cols;
                          return _buildShelf(shelf, cols, start);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _summaryChip(Color color, String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label  $count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // هر طبقه: یک خانه شیشه‌ای + یک ردیف رک + تخته قفسه
  Widget _buildShelf(int shelf, int cols, int startRack) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4, right: 4),
            child: Text(
              'طبقه $shelf',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade600),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.35)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double gap = 6;
                final double size =
                    ((constraints.maxWidth - gap * (cols - 1)) / cols).clamp(46.0, 92.0).toDouble();
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < cols; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        _buildSlot(startRack + i + 1, shelf, i + 1, size),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          // تخته قفسه
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueGrey.shade400, Colors.blueGrey.shade600],
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productImage(int? productId, String name, bool dim, double size) {
    final path = productId == null ? null : _imageById[productId];
    Widget img = ProductThumb(name: name, imagePath: path, size: size);
    if (dim) {
      img = Opacity(
        opacity: 0.45,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: img,
        ),
      );
    }
    return img;
  }

  // رنگ نوار موجودی: سبز (پر) ← زرد (متوسط) ← نارنجی (کم) ← قرمز (تمام‌شده)
  Color _gaugeColor(int stock, bool inactive) {
    if (inactive || stock == 0) return Colors.red.shade500;
    if (stock <= _lowStockThreshold) return Colors.orange.shade600;
    if (stock <= 5) return Colors.amber.shade600;
    return Colors.green.shade500;
  }

  // --- یک خانه رک روی قفسه: فقط تامبنیل + نوار موجودی ---

  Widget _buildSlot(int rackNumber, int shelf, int column, double size) {
    final rack = _racks[rackNumber];
    final bool isEmpty = rack == null;
    final bool inactive = !isEmpty && rack['status'] == 0;
    final int stock = isEmpty ? 0 : rack['stock'] as int;
    final bool soldOut = !isEmpty && !inactive && stock == 0;
    final String name = isEmpty ? '' : (rack['product_name'] ?? '-').toString();
    final int price = isEmpty ? 0 : rack['current_price'] as int;

    final bool compact = size < 60;
    final double fs = compact ? 9 : 11;

    final Color gaugeColor = _gaugeColor(stock, inactive);
    final double fill = (stock / _rackCapacity).clamp(0.0, 1.0).toDouble();

    final Widget imageArea = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isEmpty ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: inactive ? Colors.red.shade500 : (isEmpty ? Colors.blueGrey.shade200 : Colors.white),
          width: inactive ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isEmpty)
              Center(child: Icon(Icons.add, color: Colors.blueGrey.shade200, size: compact ? 18 : 26))
            else
              _productImage(rack['product_id'] as int?, name, soldOut || inactive, size),
            // شماره رک (ملایم و کوچک)
            Positioned(
              top: 3,
              right: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rackNumber',
                  style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
                ),
              ),
            ),
            // علامت اخطار رک غیرفعال
            if (inactive)
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  width: compact ? 16 : 20,
                  height: compact ? 16 : 20,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 3)],
                  ),
                  child: Icon(Icons.priority_high, color: Colors.white, size: compact ? 12 : 15),
                ),
              ),
          ],
        ),
      ),
    );

    // نوار سطح موجودی + عدد
    final Widget gauge = isEmpty
        ? SizedBox(height: compact ? 12 : 14)
        : Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 7, color: Colors.blueGrey.shade100),
                      FractionallySizedBox(
                        widthFactor: fill,
                        child: Container(height: 7, color: gaugeColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$stock',
                style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: gaugeColor),
              ),
            ],
          );

    return InkWell(
      onTap: () => _openRackEditor(rackNumber, shelf, column),
      borderRadius: BorderRadius.circular(10),
      child: Tooltip(
        message: isEmpty
            ? 'رک خالی (آدرس ${shelf * 1000 + column})'
            : '$name | ${price.toRial} | موجودی $stock${inactive ? ' | غیرفعال' : ''}',
        child: SizedBox(
          width: size,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              imageArea,
              const SizedBox(height: 5),
              gauge,
            ],
          ),
        ),
      ),
    );
  }
}