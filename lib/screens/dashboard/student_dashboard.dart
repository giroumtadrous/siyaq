import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/progress_report.dart';
import '../../models/session_model.dart';
import '../../models/tutor_profile.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/progress_service.dart';
import '../../services/tutor_directory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_widgets.dart';
import '../booking/trial_booking_screen.dart';
import '../directory/tutor_directory_screen.dart';
import '../directory/tutor_widgets.dart';
import 'student/next_class_card.dart';
import 'student/student_sections.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late final String _uid = context.read<AuthService>().currentUser?.uid ?? '';
  late final Stream<List<TutoringSession>> _sessions =
      context.read<BookingService>().sessionsForUser(_uid);
  late final Stream<List<ProgressReport>> _reports =
      context.read<ProgressService>().reportsForStudent(_uid);
  late final Stream<List<TutorProfile>> _tutors =
      context.read<TutorDirectoryService>().activeTutors();
  late final Stream<Map<String, int>> _ratings =
      context.read<TutorDirectoryService>().myRatings(_uid);

  // Re-evaluates countdowns and the join window.
  Timer? _tick;
  DateTime _now = DateTime.now();
  bool _showUpcoming = true;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
        const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _book() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const TrialBookingScreen()));

  void _browseTutors() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const TutorDirectoryScreen()));

  Future<void> _rate(TutoringSession s) async {
    final rating = await showDialog<int>(
        context: context, builder: (_) => RateSessionDialog(subject: s.subject));
    if (rating == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<TutorDirectoryService>().rateSession(s, rating);
      messenger.showSnackBar(const SnackBar(content: Text('شكراً! تم حفظ تقييمك')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('تعذّر حفظ التقييم، حاول مرة أخرى')));
    }
  }

  String get _greeting => _now.hour < 12 ? 'صباح الخير' : 'مساء الخير';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final firstName = (auth.currentUser?.name ?? '').trim().split(' ').first;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: StreamBuilder<List<TutoringSession>>(
          stream: _sessions,
          builder: (context, sessionSnap) => StreamBuilder<List<ProgressReport>>(
            stream: _reports,
            builder: (context, reportSnap) {
              final ready = sessionSnap.hasData && reportSnap.hasData;
              final failed = sessionSnap.hasError || reportSnap.hasError;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(onSignOut: auth.signOut),
                        const SizedBox(height: 24),
                        if (failed)
                          const DashNotice(
                              icon: Icons.error_outline_rounded,
                              text:
                                  'تعذّر تحميل بياناتك. تحقق من الاتصال ثم أعد فتح الصفحة.')
                        else if (!ready)
                          const _Skeleton()
                        else
                          ..._content(
                            name: firstName,
                            sessions: sessionSnap.data!,
                            reports: reportSnap.data!,
                            wide: wide,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _content({
    required String name,
    required List<TutoringSession> sessions,
    required List<ProgressReport> reports,
    required bool wide,
  }) {
    bool isUpcoming(TutoringSession s) =>
        s.scheduledAt.isAfter(_now.subtract(const Duration(hours: 2))) &&
        (s.status == SessionStatus.pending || s.status == SessionStatus.confirmed);

    final upcoming = sessions.where(isUpcoming).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final past = sessions.where((s) => !isUpcoming(s)).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    final completed = sessions.where((s) => s.status == SessionStatus.completed).length;
    final hasToday = upcoming.any((s) {
      final d = s.scheduledAt.toLocal();
      return d.year == _now.year && d.month == _now.month && d.day == _now.day;
    });

    // Ratings and the directory load on their own, so a failure there never
    // hides the schedule.
    final schedule = StreamBuilder<Map<String, int>>(
      stream: _ratings,
      builder: (context, ratingSnap) => ScheduleSection(
        upcoming: upcoming,
        past: past,
        showUpcoming: _showUpcoming,
        onTab: (v) => setState(() => _showUpcoming = v),
        onBook: _book,
        now: _now,
        ratings: ratingSnap.data ?? const {},
        onRate: ratingSnap.hasData ? _rate : null,
      ),
    );
    final tutors = StreamBuilder<List<TutorProfile>>(
      stream: _tutors,
      builder: (context, tutorSnap) => TopTutorsSection(
        tutors: tutorSnap.hasError ? const [] : tutorSnap.data,
        onBrowse: _browseTutors,
      ),
    );
    final progress = ProgressSection(reports: reports, completed: completed);
    final code = LinkCodeSection(code: _uid);

    const gap = SizedBox(height: 20);
    return [
      Semantics(
        header: true,
        child: Text(name.isEmpty ? _greeting : '$_greeting، $name',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 4),
      Text(
        upcoming.isEmpty
            ? 'ابدأ بحجز أول حصة لك.'
            : hasToday
                ? 'لديك حصة اليوم.'
                : 'لا توجد حصص اليوم.',
        style: const TextStyle(color: AppColors.muted, fontSize: 15),
      ),
      const SizedBox(height: 20),
      if (upcoming.isNotEmpty) ...[
        NextClassCard(session: upcoming.first, now: _now),
        gap,
      ],
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: schedule),
          const SizedBox(width: 20),
          Expanded(
              flex: 2,
              child: Column(children: [tutors, gap, progress, gap, code])),
        ])
      else ...[schedule, gap, tutors, gap, progress, gap, code],
    ];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.indigo, borderRadius: BorderRadius.circular(10)),
          child: const Text('س',
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        const Text('سياق', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const Spacer(),
        IconButton(
          onPressed: onSignOut,
          tooltip: 'تسجيل الخروج',
          icon: const Icon(Icons.logout_rounded),
        ),
      ]);
}

/// Placeholder blocks shaped like the real content while data loads.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24)),
        );
    return Semantics(
      label: 'جارٍ التحميل',
      child: ExcludeSemantics(child: Column(children: [block(28), block(190), block(260)])),
    );
  }
}
