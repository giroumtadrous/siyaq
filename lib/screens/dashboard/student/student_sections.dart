import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../models/progress_report.dart';
import '../../../models/session_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/dashboard_widgets.dart';
import 'next_class_card.dart';

const _danger = Color(0xFFDC2626);

// ───────────────────────── Schedule ─────────────────────────

String _dayLabel(DateTime d, DateTime now) {
  final diff = DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  return switch (diff) {
    0 => 'اليوم',
    1 => 'غداً',
    -1 => 'أمس',
    _ => DateFormat('EEEE d MMMM', 'ar').format(d),
  };
}

/// Sessions as one list grouped by day: time on the start side, a status
/// that's spelled out in words and an icon, never colour alone.
class ScheduleSection extends StatelessWidget {
  const ScheduleSection({
    super.key,
    required this.upcoming,
    required this.past,
    required this.showUpcoming,
    required this.onTab,
    required this.onBook,
    required this.now,
  });
  final List<TutoringSession> upcoming, past;
  final bool showUpcoming;
  final ValueChanged<bool> onTab;
  final VoidCallback onBook;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final list = showUpcoming ? upcoming : past;
    final rows = <Widget>[];
    String? lastLabel;
    for (final s in list) {
      final when = s.scheduledAt.toLocal();
      final label = _dayLabel(when, now);
      if (label != lastLabel) {
        rows.add(Padding(
          padding: EdgeInsets.only(top: lastLabel == null ? 0 : 18, bottom: 4),
          child: Semantics(
            header: true,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ));
        lastLabel = label;
      } else {
        rows.add(const Divider(height: 1, color: AppColors.border));
      }
      rows.add(_SessionRow(session: s));
    }

    return DashPanel(
      title: 'حصصي',
      trailing: TextButton.icon(
        onPressed: onBook,
        icon: const Icon(Icons.add_rounded),
        label: const Text('احجز حصة'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, children: [
          DashTabChip('القادمة (${arabicNumber(upcoming.length)})', showUpcoming,
              () => onTab(true)),
          DashTabChip(
              'السابقة (${arabicNumber(past.length)})', !showUpcoming, () => onTab(false)),
        ]),
        const SizedBox(height: 16),
        if (list.isEmpty)
          _EmptySchedule(upcoming: showUpcoming, onBook: onBook)
        else
          ...rows,
      ]),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.upcoming, required this.onBook});
  final bool upcoming;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(children: [
          Text(upcoming ? 'لا توجد حصص قادمة' : 'لم تنتهِ أي حصة بعد',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
              upcoming
                  ? 'احجز حصتك التجريبية الأولى مجاناً وبدون التزام.'
                  : 'ستظهر هنا الحصص المكتملة والملغاة.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.6)),
          if (upcoming) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onBook, child: const Text('احجز حصة تجريبية مجانية')),
          ],
        ]),
      );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final TutoringSession session;

  (IconData, String, Color) get _status => switch (session.status) {
        SessionStatus.pending => (Icons.hourglass_top_rounded, 'بانتظار التأكيد', AppColors.amber),
        SessionStatus.confirmed => (Icons.check_circle_rounded, 'مؤكدة', AppColors.mint),
        SessionStatus.completed => (Icons.task_alt_rounded, 'مكتملة', AppColors.indigo),
        SessionStatus.cancelled => (Icons.cancel_rounded, 'ملغاة', _danger),
      };

  @override
  Widget build(BuildContext context) {
    final when = session.scheduledAt.toLocal();
    final (icon, label, color) = _status;
    final text = readableOn(color);
    final time = DateFormat('h:mm a', 'ar').format(when);
    final subject = session.subject.isEmpty ? 'حصة' : session.subject;

    return Semantics(
      container: true,
      label: '$subject، $time، $label',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          SizedBox(
            width: 84,
            child: Text(time,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (session.isTrial)
                const Text('حصة تجريبية',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: text),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

// ───────────────────────── Progress ─────────────────────────

/// Latest score per subject, plus the most recent tutor note.
class ProgressSection extends StatelessWidget {
  const ProgressSection({super.key, required this.reports, required this.completed});
  final List<ProgressReport> reports; // newest first
  final int completed;

  @override
  Widget build(BuildContext context) {
    final latest = <String, ProgressReport>{};
    for (final r in reports) {
      latest.putIfAbsent(r.subject, () => r);
    }
    final note = reports.where((r) => r.notes.isNotEmpty).firstOrNull;

    return DashPanel(
      title: 'تقدمي',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('أكملت ${arabicNumber(completed)} ${completed == 1 ? 'حصة' : 'حصص'}',
            style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        if (latest.isEmpty)
          const Text('ستظهر نتائجك هنا بعد أول تقرير من معلمك.',
              style: TextStyle(color: AppColors.muted, height: 1.6))
        else
          for (final r in latest.values) _ScoreBar(report: r),
        if (note != null) ...[
          const Divider(height: 28, color: AppColors.border),
          const Text('آخر ملاحظة من المعلم',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(note.notes, style: const TextStyle(height: 1.7)),
        ],
      ]),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.report});
  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final color = report.score >= 80
        ? AppColors.mint
        : report.score >= 50
            ? AppColors.amber
            : _danger;
    final pct = '${arabicNumber(report.score.round())}٪';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        label: '${report.subject}: $pct',
        excludeSemantics: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(report.subject,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(pct, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: report.score / 100,
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.surface,
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Parent link code ─────────────────────────

class LinkCodeSection extends StatelessWidget {
  const LinkCodeSection({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: const Text('ربط ولي الأمر',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            subtitle: const Text('ليتابع حصصك وتقاريرك',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            children: [
              const Text(
                'أعطِ هذا الرمز لولي أمرك ليدخله في حسابه. لا تشاركه مع غيره.',
                style: TextStyle(color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(
                    child: SelectableText(code,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
                  IconButton(
                    tooltip: 'نسخ الرمز',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('تم نسخ الرمز')));
                    },
                  ),
                ]),
              ),
            ],
          ),
        ),
      );
}
