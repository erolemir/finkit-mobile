import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

final _money = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);
final _date = DateFormat('dd.MM.yyyy');

String moneyText(dynamic value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  return _money.format(number);
}

String dateText(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  return parsed == null ? '—' : _date.format(parsed);
}

/// Rapor anahtarını ekranda gösterilecek başlığa çevirir.
String reportTitle(String report) {
  return switch (report) {
    'sales' => 'Satış Raporu',
    'collections' => 'Tahsilat Raporu',
    'expenses' => 'Gider Raporu',
    'payments' => 'Ödemeler Raporu',
    'vat' => 'KDV Raporu',
    'income-expense' => 'Gelir-Gider Raporu',
    'cash-flow' => 'Nakit Akışı',
    'cash-register' => 'Kasa Raporu',
    'stock' => 'Stok Raporu',
    'aging' => 'Vade Yaşlandırma',
    'payroll' => 'Bordro Raporu',
    _ => 'Rapor',
  };
}

String statusLabel(String? value) {
  const labels = {
    'DRAFT': 'Taslak',
    'SENT': 'Gönderildi',
    'FINALIZED': 'Kesinleşti',
    'DELIVERED': 'Teslim edildi',
    'ACCEPTED': 'Kabul edildi',
    'REJECTED': 'Reddedildi',
    'CANCELLED': 'İptal edildi',
    'ERROR': 'Hata',
    'NEEDS_MATCH': 'Eşleşme bekliyor',
    'POSTED': 'Kaydedildi',
    'PAID': 'Ödendi',
    'PARTIAL': 'Kısmi ödendi',
    'UNPAID': 'Ödenmedi',
    'OVERDUE': 'Gecikti',
    'CONVERTED': 'Faturaya dönüştü',
    'CASH': 'Kasa',
    'BANK': 'Banka',
    'POS': 'POS',
    'CREDIT_CARD': 'Kredi kartı',
    'ACTIVE': 'Aktif',
    'INACTIVE': 'Pasif',
    'TERMINATED': 'Ayrıldı',
    'MANUAL': 'Manuel',
    'COLLECTION': 'Tahsilat',
    'EXPENSE': 'Gider',
    'PAYROLL': 'Bordro',
    'SUPPLIER_PAYMENT': 'Tedarikçi ödemesi',
    'CHECK_NOTE_EVENT': 'Çek/senet',
    'SALES_INVOICE': 'Satış faturası',
    'PURCHASE_INVOICE': 'Gelen fatura',
  };
  return labels[value?.toUpperCase()] ??
      (value?.isNotEmpty == true ? 'Bilinmiyor' : '—');
}

Color statusColor(String? value) {
  switch (value?.toUpperCase()) {
    case 'PAID':
    case 'ACCEPTED':
    case 'POSTED':
    case 'FINALIZED':
    case 'DELIVERED':
    case 'ACTIVE':
    case 'CLOSED':
      return FinkitColors.success;
    case 'CANCELLED':
    case 'REJECTED':
    case 'ERROR':
    case 'OVERDUE':
    case 'TERMINATED':
      return FinkitColors.danger;
    case 'DRAFT':
    case 'SENT':
    case 'PARTIAL':
    case 'NEEDS_MATCH':
    case 'UNPAID':
    case 'WAITING':
      return FinkitColors.warning;
    default:
      return FinkitColors.muted;
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: FinkitColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.foot,
    this.dark = false,
    this.status,
    this.width,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? foot;
  final bool dark;
  final String? status;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 166),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? null : FinkitColors.surface,
          gradient: dark
              ? const LinearGradient(
                  colors: [FinkitColors.ink, FinkitColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: dark ? Colors.transparent : FinkitColors.line,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A17202B),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.12)
                        : FinkitColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: dark ? Colors.white : FinkitColors.ink,
                  ),
                ),
                const Spacer(),
                if (status != null) StatusPill(label: status!, value: status),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                color: dark
                    ? Colors.white.withValues(alpha: 0.68)
                    : FinkitColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark ? Colors.white : FinkitColors.text,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
            ),
            if (foot != null) ...[
              const SizedBox(height: 8),
              Text(
                foot!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.62)
                      : FinkitColors.mutedLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(value ?? label);
    final soft = switch (color) {
      FinkitColors.success => FinkitColors.successSoft,
      FinkitColors.warning => FinkitColors.warningSoft,
      FinkitColors.danger => FinkitColors.dangerSoft,
      _ => const Color(0xFFEEF0F3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 17),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  color: FinkitColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.dark = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool dark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? null : FinkitColors.surface,
        gradient: dark
            ? const LinearGradient(
                colors: [FinkitColors.ink, FinkitColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? Colors.transparent : FinkitColors.line,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0917202B),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: card,
    );
  }
}

class DataRowCard extends StatelessWidget {
  const DataRowCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.valueSubtitle,
    this.status,
    this.positive,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String? valueSubtitle;
  final String? status;
  final bool? positive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: FinkitColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 21, color: FinkitColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FinkitColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: positive == null
                      ? FinkitColors.text
                      : positive!
                      ? FinkitColors.success
                      : FinkitColors.danger,
                ),
              ),
              const SizedBox(height: 4),
              if (status != null)
                StatusPill(label: statusLabel(status), value: status)
              else if (valueSubtitle != null)
                Text(
                  valueSubtitle!,
                  style: const TextStyle(
                    color: FinkitColors.mutedLight,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Icon(icon, size: 44, color: FinkitColors.mutedLight),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FinkitColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: FinkitColors.ink,
          ),
        ),
      ),
    );
  }
}

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    const income = [42.0, 58.0, 46.0, 72.0, 88.0, 76.0];
    const expense = [28.0, 36.0, 30.0, 44.0, 39.0, 34.0];
    return Column(
      children: [
        SizedBox(
          height: 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              income.length,
              (index) => Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: income[index],
                      decoration: const BoxDecoration(
                        color: FinkitColors.ink,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(7),
                          bottom: Radius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      width: 10,
                      height: expense[index],
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9DDE3),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nis',
              style: TextStyle(color: FinkitColors.mutedLight, fontSize: 9),
            ),
            Text(
              'May',
              style: TextStyle(color: FinkitColors.mutedLight, fontSize: 9),
            ),
            Text(
              'Haz',
              style: TextStyle(color: FinkitColors.mutedLight, fontSize: 9),
            ),
            Text(
              'Tem',
              style: TextStyle(color: FinkitColors.mutedLight, fontSize: 9),
            ),
            Text(
              'Ağu',
              style: TextStyle(color: FinkitColors.mutedLight, fontSize: 9),
            ),
            Text(
              'Eyl',
              style: TextStyle(color: FinkitColors.mutedLight, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }
}

class CollectionDonut extends StatelessWidget {
  const CollectionDonut({super.key, this.percent = 82});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 116,
        height: 116,
        child: CustomPaint(
          painter: _DonutPainter(percent),
          child: Center(
            child: Text(
              '%${percent.round()}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.percent);

  final double percent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 7;
    final background = Paint()
      ..color = const Color(0xFFEDF0F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..color = FinkitColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * (percent / 100),
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.percent != percent;
}

class Sparkline extends StatelessWidget {
  const Sparkline({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter()),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = FinkitColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x22111318), Color(0x00111318)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    final values = [0.68, 0.58, 0.74, 0.48, 0.52, 0.31, 0.38, 0.18, 0.26, 0.08];
    final path = Path();
    final fillPath = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y = size.height * values[index];
      if (index == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QuickTile extends StatelessWidget {
  const QuickTile({
    super.key,
    required this.icon,
    required this.label,
    this.primary = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? FinkitColors.ink : FinkitColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? Colors.transparent : FinkitColors.line,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0917202B),
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
          ],
        ),
        // Dar telefon ekranlarında kutu yüksekliği küçüldüğü için ikon ve
        // boşluklar mevcut alana göre daraltılır; taşma oluşmaz.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 104;
            final iconBox = compact ? 34.0 : 42.0;
            final iconGlyph = compact ? 18.0 : 21.0;
            final gap = compact ? 5.0 : 9.0;
            final fontSize = compact ? 10.0 : 11.0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.12)
                        : FinkitColors.primarySoft,
                    borderRadius: BorderRadius.circular(compact ? 11 : 14),
                  ),
                  child: Icon(
                    icon,
                    color: primary ? Colors.white : FinkitColors.ink,
                    size: iconGlyph,
                  ),
                ),
                SizedBox(height: gap),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary ? Colors.white : FinkitColors.text,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
