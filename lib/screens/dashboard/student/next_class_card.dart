import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:url_launcher/url_launcher.dart';

import '../../../models/session_model.dart';
import '../../../theme/app_theme.dart';

/// How early the join button unlocks.
const joinLeadTime = Duration(minutes: 15);

/// How long after the start a class still counts as running.
const classLength = Duration(minutes: 90);

String arabicNumber(num v) => NumberFormat.decimalPattern('ar').format(v);

String _startsIn(Duration d) {
  if (d.inMinutes < 1) return 'تبدأ الآن';
  if (d.inMinutes < 60) return 'تبدأ بعد ${arabicNumber(d.inMinutes)} دقيقة';
  if (d.inHours < 24) {
    final m = d.inMinutes % 60;
    final h = arabicNumber(d.inHours);
    return m == 0 ? 'تبدأ بعد $h ساعة' : 'تبدأ بعد $h ساعة و${arabicNumber(m)} دقيقة';
  }
  final days = d.inDays;
  if (days == 1) return 'تبدأ بعد يوم';
  if (days == 2) return 'تبدأ بعد يومين';
  return 'تبدأ بعد ${arabicNumber(days)} أيام';
}

/// The one prominent element on the student dashboard: what's next, when it
/// starts, and whether the student can join yet.
class NextClassCard extends StatelessWidget {
  const NextClassCard({super.key, required this.session, required this.now});
  final TutoringSession session;
  final DateTime now;

  (IconData, String) get _status {
    if (session.status == SessionStatus.confirmed) {
      return (Icons.check_circle_rounded, 'مؤكدة');
    }
    return session.tutorId == unassignedTutorId
        ? (Icons.hourglass_top_rounded, 'بانتظار تعيين معلم')
        : (Icons.hourglass_top_rounded, 'بانتظار تأكيد المعلم');
  }

  @override
  Widget build(BuildContext context) {
    final start = session.scheduledAt.toLocal();
    final until = start.difference(now);
    final started = until.isNegative;
    final confirmed = session.status == SessionStatus.confirmed;
    final live = started && confirmed && now.isBefore(start.add(classLength));
    final link = session.googleMeetLink;
    final hasLink = link != null && link.isNotEmpty;
    final canJoin = confirmed &&
        hasLink &&
        until <= joinLeadTime &&
        now.isBefore(start.add(const Duration(hours: 2)));

    final headline = live
        ? 'جارية الآن'
        : started
            ? 'حان موعد الحصة'
            : _startsIn(until);
    final (statusIcon, statusText) = _status;

    final String? hint = canJoin
        ? null
        : !confirmed
            ? 'سيظهر زر الانضمام بعد تأكيد المعلم.'
            : !hasLink
                ? 'سيضيف المعلم رابط الحصة قبل الموعد.'
                : 'يفتح الانضمام قبل الموعد بـ ${arabicNumber(joinLeadTime.inMinutes)} دقيقة.';

    return Semantics(
      container: true,
      label: 'الحصة القادمة: ${session.subject}. $headline. $statusText',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(statusText,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            if (live) ...[const PulseDot(), const SizedBox(width: 10)],
            Flexible(
              child: Text(headline,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(session.subject.isEmpty ? 'حصة' : session.subject,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            '${DateFormat('EEEE d MMMM • h:mm a', 'ar').format(start)}'
            '${session.isTrial ? ' • حصة تجريبية' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          if (canJoin)
            FilledButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.video_call_rounded),
              label: const Text('انضم إلى الحصة'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mint,
                foregroundColor: AppColors.ink,
                minimumSize: const Size(0, 52),
              ),
            )
          else
            Text(hint!, style: const TextStyle(color: Colors.white70, height: 1.6)),
        ]),
      ),
    );
  }
}

/// Small pulsing dot for "live now". Stays still when the user has asked the
/// system to reduce motion.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
          child: Container(
            width: 12,
            height: 12,
            decoration:
                const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
          ),
        ),
      );
}
