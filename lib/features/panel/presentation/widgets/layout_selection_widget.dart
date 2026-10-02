import 'package:flutter/material.dart';
import '../../../../core/database/vending_repository.dart';
import '../../../../core/utils/extensions.dart';
import '../../../admin/presentation/widgets/product_thumb.dart';

/// پنل خرید مشتری در حالت «چیدمان رک‌ها»: هر طبقه یک ردیف تمام‌عرض
class LayoutSelectionWidget extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final ValueChanged<int> onRackTap;

  const LayoutSelectionWidget({
    super.key,
    required this.cart,
    required this.onRackTap,
  });

  @override
  State<LayoutSelectionWidget> createState() => _LayoutSelectionWidgetState();
}

class _LayoutSelectionWidgetState extends State<LayoutSelectionWidget> {
  final VendingRepository _repo = VendingRepository();
  List<Map<String, dynamic>> _layout = [];
  Map<int, Map<String, dynamic>> _racks = {};
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
      _imageById = {for (var p in products) p['id'] as int: p['image_path'] as String};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_layout.isEmpty) {
      return Center(
        child: Text(
          'دستگاه هنوز پیکربندی نشده است',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      );
    }

    int baseRack = 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.08), blurRadius: 15, spreadRadius: 1)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _layout.map((row) {
              final int cols = row['columns_count'] as int;
              final int start = baseRack;
              baseRack += cols;
              return _buildShelf(cols, start);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildShelf(int cols, int startRack) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const double gap = 6;
              final double size =
                  ((constraints.maxWidth - gap * (cols - 1)) / cols).clamp(40.0, 120.0).toDouble();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < cols; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      _buildTile(startRack + i + 1, size),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Container(
            height: 7,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueGrey.shade300, Colors.blueGrey.shade500],
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3, offset: const Offset(0, 2))],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(int rackNumber, double size) {
    final rack = _racks[rackNumber];
    final bool isEmpty = rack == null;
    final bool inactive = !isEmpty && rack['status'] == 0;
    final int stock = isEmpty ? 0 : rack['stock'] as int;
    final bool unavailable = inactive || (!isEmpty && stock <= 0);
    final String name = isEmpty ? '' : (rack['product_name'] ?? '').toString();
    final int price = isEmpty ? 0 : rack['current_price'] as int;
    final int? productId = isEmpty ? null : rack['product_id'] as int?;
    final String? imagePath = productId == null ? null : _imageById[productId];
    final int inCart = widget.cart.where((i) => i['rack_number'] == rackNumber).length;

    final bool compact = size < 64;
    final double fs = compact ? 9 : 11;

    Widget thumb = isEmpty
        ? Center(child: Icon(Icons.remove, color: Colors.grey.shade300, size: compact ? 16 : 22))
        : ProductThumb(name: name, imagePath: imagePath, size: size, radius: 10);
    if (unavailable) {
      thumb = Opacity(
        opacity: 0.4,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: thumb,
        ),
      );
    }

    final Widget imageArea = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isEmpty ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inCart > 0 ? Colors.green.shade500 : Colors.grey.shade200, width: inCart > 0 ? 2 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            thumb,
            if (!isEmpty)
              Positioned(
                top: 3,
                right: 4,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$rackNumber',
                    style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
                  ),
                ),
              ),
            if (inCart > 0)
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  width: compact ? 16 : 20,
                  height: compact ? 16 : 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle),
                  child: Text(
                    '$inCart',
                    style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return InkWell(
      onTap: isEmpty ? null : () => widget.onRackTap(rackNumber),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            imageArea,
            const SizedBox(height: 3),
            SizedBox(
              height: fs + 5,
              child: isEmpty
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        unavailable ? 'ناموجود' : price.toRial,
                        style: TextStyle(
                          fontSize: fs + 1,
                          fontWeight: FontWeight.bold,
                          color: unavailable ? Colors.red.shade600 : Colors.green.shade700,
                        ),
                      ),
                    ),
            ),
            SizedBox(
              height: fs + 4,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: fs, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}