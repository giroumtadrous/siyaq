import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gradient greeting card with a sign-out button.
class DashHeader extends StatelessWidget {
  const DashHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onSignOut,
  });
  final String name;
  final String subtitle;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مرحباً ${name.isEmpty ? 'بك' : name} 👋',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
            ]),
          ),
          IconButton.filled(
            onPressed: onSignOut,
            tooltip: 'تسجيل الخروج',
            style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18)),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ]),
      );
}

class DashNotice extends StatelessWidget {
  const DashNotice({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted))),
        ]),
      );
}

class DashPanel extends StatelessWidget {
  const DashPanel({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ]),
      );
}

class DashTabChip extends StatelessWidget {
  const DashTabChip(this.label, this.selected, this.onTap, {super.key});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        label: Text(label),
        labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.ink),
        selectedColor: AppColors.indigo,
        backgroundColor: AppColors.surface,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

class DashBadge extends StatelessWidget {
  const DashBadge(this.text, this.color, {super.key});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Text(text,
            style: TextStyle(color: readableOn(color), fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

/// Darkens an accent so text in it stays readable on its own light tint
/// (amber at full strength is only ~2:1 against white).
Color readableOn(Color accent) =>
    HSLColor.fromColor(accent).withLightness(0.3).toColor();

class DashStat {
  const DashStat(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

/// Row (wraps to a 2-column grid on narrow screens) of stat tiles.
class DashStats extends StatelessWidget {
  const DashStats({super.key, required this.items});
  final List<DashStat> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 560 ? items.length : 2;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final t in items)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(t.icon, color: t.color),
                  const SizedBox(height: 10),
                  Text(t.value,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  Text(t.label,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
            ),
        ]);
      });
}
