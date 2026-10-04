// مسیر: lib/features/admin/presentation/widgets/report_widgets.dart
import 'package:flutter/material.dart';
import '../../../../core/database/order_repository.dart';
import '../../../../core/database/report_repository.dart';
import '../../../../core/utils/csv_export.dart';

/// اجزای مشترک صفحه‌های گزارش و لاگ پنل مدیریت

const Color kReportInk = Color(0xFF2B3A47);
const Color kReportBg = Color(0xFFF5F7FA);

/// رنگ و آیکون وضعیت سفارش؛ رنگ هیچ‌وقت تنها نشانه نیست و همیشه متن وضعیت کنارش می‌آید
({Color color, IconData icon}) orderStatusStyle(String status) {
  switch (status) {
    case OrderStatus.paid:
      return (color: Colors.green.shade700, icon: Icons.check_circle_outline);
    case OrderStatus.settlementDue:
      return (color: Colors.red.shade700, icon: Icons.payments_outlined);
    case OrderStatus.needsReview:
    case OrderStatus.paymentTimeout:
    case OrderStatus.posError:
      return (color: Colors.orange.shade800, icon: Icons.help_outline);
    case OrderStatus.declined:
    case OrderStatus.cancelled:
      return (color: Colors.blueGrey.shade600, icon: Icons.block);
    default:
      return (color: Colors.blueGrey.shade600, icon: Icons.hourglass_empty);
  }
}

({Color color, IconData icon}) itemStatusStyle(String status) {
  switch (status) {
    case ItemStatus.delivered:
      return (color: Colors.green.shade700, icon: Icons.check_circle);
    case ItemStatus.failed:
      return (color: Colors.red.shade700, icon: Icons.cancel);
    case ItemStatus.unknown:
      return (color: Colors.orange.shade800, icon: Icons.help);
    default:
      return (color: Colors.blueGrey.shade600, icon: Icons.remove_circle_outline);
  }
}

Color logTypeColor(String type) {
  switch (type) {
    case 'HARD':
      return Colors.red.shade700;
    case 'SOFT':
      return Colors.orange.shade800;
    default:
      return Colors.blueGrey.shade600;
  }
}

IconData logTypeIcon(String type) {
  switch (type) {
    case 'HARD':
      return Icons.error_outline;
    case 'SOFT':
      return Icons.warning_amber_rounded;
    default:
      return Icons.info_outline;
  }
}

/// قالب صفحه گزارش: نوار بالا مثل پنل مدیریت + پس‌زمینه روشن + راست‌به‌چپ
class ReportPage extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;

  const ReportPage({super.key, required this.title, this.actions = const [], required this.body});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kReportBg,
        appBar: AppBar(
          backgroundColor: Colors.blueGrey.shade800,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          actions: actions,
        ),
        body: body,
      ),
    );
  }
}

/// ردیف انتخاب بازه زمانی
class RangeChips extends StatelessWidget {
  final List<ReportRange> ranges;
  final String selectedKey;
  final ValueChanged<ReportRange> onSelected;

  const RangeChips({super.key, required this.ranges, required this.selectedKey, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in ranges)
          ChoiceChip(
            label: Text(r.label),
            selected: r.key == selectedKey,
            onSelected: (_) => onSelected(r),
            visualDensity: VisualDensity.standard,
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: r.key == selectedKey ? Colors.white : kReportInk,
            ),
            selectedColor: Colors.blueGrey.shade700,
            backgroundColor: Colors.white,
            checkmarkColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300),
          ),
      ],
    );
  }
}

/// کارت سفید با عنوان
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(child: Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kReportInk))),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// کاشی عدد کلیدی
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  final bool hero;

  const StatTile({super.key, required this.label, required this.value, this.sub, this.subColor, this.hero = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: TextStyle(fontSize: hero ? 30 : 22, fontWeight: FontWeight.bold, color: kReportInk)),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: TextStyle(fontSize: 12, color: subColor ?? Colors.grey.shade600, fontWeight: subColor == null ? FontWeight.normal : FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

/// چیدمان کاشی‌ها: ۲ ستون در عرض کم و ۴ ستون در عرض زیاد؛ کاشی‌های هر ردیف هم‌ارتفاع‌اند
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 900 ? 4 : 2;
        const double gap = 12;
        final rows = <Widget>[];
        for (int start = 0; start < children.length; start += columns) {
          final rowChildren = <Widget>[];
          for (int i = 0; i < columns; i++) {
            if (i > 0) rowChildren.add(const SizedBox(width: gap));
            final int index = start + i;
            rowChildren.add(Expanded(child: index < children.length ? children[index] : const SizedBox.shrink()));
          }
          if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
          rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren)));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      },
    );
  }
}

/// ظاهر دکمه‌های تب (SegmentedButton) هماهنگ با نوار بالای پنل مدیریت
ButtonStyle reportSegmentStyle() {
  return SegmentedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: kReportInk,
    selectedBackgroundColor: Colors.blueGrey.shade700,
    selectedForegroundColor: Colors.white,
    side: BorderSide(color: Colors.grey.shade300),
  );
}

/// برچسب کوچک رنگی
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const Pill({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class OrderStatusPill extends StatelessWidget {
  final String status;
  const OrderStatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final style = orderStatusStyle(status);
    return Pill(text: ReportLabels.order(status), color: style.color, icon: style.icon);
  }
}

/// متن چپ‌به‌راست قابل انتخاب (کد پیگیری و مرجع پوز)
class LtrText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  /// false برای جاهایی که لمس متن باید به والدش (مثلاً ردیف قابل کلیک) برسد
  final bool selectable;

  const LtrText(this.text, {super.key, this.style, this.selectable = true});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: selectable ? SelectableText(text, style: style) : Text(text, style: style),
    );
  }
}

class EmptyBox extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyBox(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorBox({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: Colors.red.shade600),
            const SizedBox(height: 10),
            Text('خواندن اطلاعات ناموفق بود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('تلاش مجدد')),
          ],
        ),
      ),
    );
  }
}

/// دکمه «نمایش بیشتر» انتهای فهرست‌های صفحه‌بندی‌شده
class LoadMoreButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const LoadMoreButton({super.key, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.expand_more),
          label: Text(loading ? 'در حال بارگذاری...' : 'نمایش بیشتر'),
        ),
      ),
    );
  }
}

/// ذخیره فایل CSV و نمایش آدرس آن؛ خطا هم به کاربر نشان داده می‌شود
Future<void> saveCsvAndNotify(BuildContext context, {required String name, required Future<String> Function() buildCsv}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final csv = await buildCsv();
    final path = await CsvExporter.save(name, csv);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.file_download_done_outlined, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('فایل ذخیره شد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('فایل گزارش را با اکسل باز کنید. محل ذخیره:', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              LtrText(path, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('ذخیره فایل ناموفق بود: $e'), backgroundColor: Colors.red.shade700));
  }
}