import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../data/curriculum.dart';
import '../../theme/app_theme.dart';

/// Earliest a booking can start, counted from now.
const bookingLeadTime = Duration(hours: 2);

/// How many days ahead a student can book.
const bookingHorizonDays = 14;

/// First and last bookable hour of the day (24h clock, last slot inclusive).
const _firstHour = 9;
const _lastHour = 21;

/// Subjects offered for booking.
List<Subject> bookableSubjects() => allSubjects();

/// Hourly start times on [day] that are at least [bookingLeadTime] after [now].
List<DateTime> availableSlots(DateTime day, DateTime now) {
  final earliest = now.add(bookingLeadTime);
  return [
    for (var h = _firstHour; h <= _lastHour; h++)
      if (DateTime(day.year, day.month, day.day, h).isAfter(earliest))
        DateTime(day.year, day.month, day.day, h),
  ];
}

/// Days that still have at least one open slot, starting today.
List<DateTime> bookableDays(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var i = 0; i <= bookingHorizonDays; i++)
      if (availableSlots(today.add(Duration(days: i)), now).isNotEmpty)
        today.add(Duration(days: i)),
  ];
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          header: true,
          child: Text(text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      );
}

class SubjectPicker extends StatelessWidget {
  const SubjectPicker({super.key, required this.selected, required this.onSelect});
  final Subject? selected;
  final ValueChanged<Subject> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        for (final s in bookableSubjects())
          ChoiceChip(
            selected: selected?.name == s.name,
            onSelected: (_) => onSelect(s),
            showCheckmark: false,
            avatar: Icon(s.icon,
                size: 18,
                color: selected?.name == s.name ? Colors.white : AppColors.indigo),
            label: Text(s.name),
            labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected?.name == s.name ? Colors.white : AppColors.ink),
            selectedColor: AppColors.indigo,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
      ]);
}

class DayPicker extends StatelessWidget {
  const DayPicker({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelect,
    required this.now,
  });
  final List<DateTime> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final DateTime now;

  String _caption(DateTime d) {
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return switch (diff) {
      0 => 'اليوم',
      1 => 'غداً',
      _ => DateFormat('E', 'ar').format(d),
    };
  }

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in days)
          _DayTile(
            caption: _caption(d),
            number: DateFormat('d', 'ar').format(d),
            month: DateFormat('MMM', 'ar').format(d),
            semanticLabel: DateFormat('EEEE d MMMM', 'ar').format(d),
            selected: selected != null && sameDay(selected!, d),
            onTap: () => onSelect(d),
          ),
      ]);
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.caption,
    required this.number,
    required this.month,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });
  final String caption, number, month, semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    final sub = selected ? Colors.white70 : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.indigo : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.indigo : AppColors.border),
            ),
            child: Column(children: [
              Text(caption, style: TextStyle(fontSize: 12, color: sub)),
              const SizedBox(height: 2),
              Text(number,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
              Text(month, style: TextStyle(fontSize: 11, color: sub)),
            ]),
          ),
        ),
      ),
    );
  }
}

class TimePicker extends StatelessWidget {
  const TimePicker({super.key, required this.slots, required this.selected, required this.onSelect});
  final List<DateTime> slots;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in slots)
          ChoiceChip(
            selected: selected == s,
            onSelected: (_) => onSelect(s),
            showCheckmark: false,
            label: Text(DateFormat('h:mm a', 'ar').format(s)),
            labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected == s ? Colors.white : AppColors.ink),
            selectedColor: AppColors.indigo,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
      ]);
}
