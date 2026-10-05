import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../models/session_model.dart';
import '../../models/tutor_application.dart';
import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_widgets.dart';
import 'admin/application_review_dialog.dart';

enum _SessionFilter { all, needsTutor, upcoming, completed, cancelled }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final Stream<List<AppUser>> _users = context.read<AdminService>().allUsers();
  late final Stream<Map<String, TutorApplication>> _apps =
      context.read<AdminService>().allApplications();
  late final Stream<List<TutoringSession>> _sessions =
      context.read<AdminService>().allSessions();

  UserRole _roleTab = UserRole.tutor;
  String _query = '';
  _SessionFilter _filter = _SessionFilter.needsTutor;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _setApproved(AppUser tutor, bool approved) async {
    if (!approved) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('إيقاف حساب ${tutor.name}؟'),
          content: const Text('لن يتمكن المعلم من الدخول إلى لوحته حتى تعيد اعتماده.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
              child: const Text('إيقاف'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    try {
      await context.read<AdminService>().setTutorApproved(tutor.uid, approved);
      if (mounted) _toast(approved ? 'تم اعتماد المعلم' : 'تم إيقاف المعلم');
    } catch (_) {
      if (mounted) _toast('تعذّر تنفيذ العملية، حاول مرة أخرى');
    }
  }

  Future<void> _assign(TutoringSession s, List<AppUser> tutors) async {
    final approved = tutors.where((t) => t.approved).toList();
    final tutorId = await showDialog<String>(
      context: context,
      builder: (_) => _TutorPickerDialog(tutors: approved),
    );
    if (tutorId == null || !mounted) return;
    try {
      await context.read<AdminService>().assignTutor(s.id, tutorId);
      if (mounted) _toast('تم تعيين المعلم وتأكيد الحصة');
    } catch (_) {
      if (mounted) _toast('تعذّر تعيين المعلم، حاول مرة أخرى');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: _users,
          builder: (context, userSnap) => StreamBuilder<List<TutoringSession>>(
            stream: _sessions,
            builder: (context, sessionSnap) => StreamBuilder<Map<String, TutorApplication>>(
            stream: _apps,
            builder: (context, appSnap) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width >= 900 ? 40 : 16,
                    vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DashHeader(
                          name: auth.currentUser?.name ?? '',
                          subtitle: 'إدارة المعلمين والطلاب ومتابعة كل الحصص.',
                          onSignOut: auth.signOut,
                        ),
                        const SizedBox(height: 20),
                        if (userSnap.hasError || sessionSnap.hasError || appSnap.hasError)
                          const DashNotice(
                              icon: Icons.lock_outline_rounded,
                              text:
                                  'تعذّر تحميل البيانات. تحقق من الاتصال أو صلاحيات قاعدة البيانات.')
                        else if (!userSnap.hasData || !sessionSnap.hasData || !appSnap.hasData)
                          const Padding(
                              padding: EdgeInsets.all(48),
                              child: Center(child: CircularProgressIndicator()))
                        else
                          ..._content(userSnap.data!, sessionSnap.data!, appSnap.data!),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReview(AppUser tutor, TutorApplication app) async {
    final decision = await showDialog<ApplicationStatus>(
      context: context,
      builder: (_) => ApplicationReviewDialog(tutor: tutor, application: app),
    );
    if (decision != null && mounted) {
      _toast(decision == ApplicationStatus.approved
          ? 'تم اعتماد المعلم'
          : 'تم رفض الطلب وإرسال السبب للمعلم');
    }
  }

  /// "Review" for a submitted application, "view" for a rejected one, nothing
  /// when the tutor hasn't applied yet.
  Widget? _reviewButton(AppUser tutor, TutorApplication? app) {
    if (app == null) return null;
    return app.status == ApplicationStatus.submitted
        ? FilledButton(
            onPressed: () => _openReview(tutor, app),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            child: const Text('مراجعة الطلب'))
        : TextButton(onPressed: () => _openReview(tutor, app), child: const Text('عرض الطلب'));
  }

  Widget _tutorBadge(AppUser tutor, TutorApplication? app) {
    if (tutor.approved) return const DashBadge('معتمد', AppColors.mint);
    return switch (app?.status) {
      null => const DashBadge('لم يقدّم طلباً', AppColors.muted),
      ApplicationStatus.submitted => const DashBadge('بانتظار المراجعة', AppColors.amber),
      ApplicationStatus.rejected => const DashBadge('تم الرفض', Color(0xFFDC2626)),
      ApplicationStatus.approved => const DashBadge('موقوف', Color(0xFFDC2626)),
    };
  }

  String _applicationDetail(TutorApplication? app) => app == null
      ? 'سجّل حسابه ولم يُكمل طلب الانضمام بعد.'
      : '${app.qualification} • خبرة ${app.experienceYears} سنوات • ${app.subjects.join('، ')}';

  List<Widget> _content(List<AppUser> users, List<TutoringSession> sessions,
      Map<String, TutorApplication> apps) {
    final byId = {for (final u in users) u.uid: u};
    String nameOf(String id) {
      final u = byId[id];
      if (u == null) return id == unassignedTutorId ? 'غير معيّن' : '—';
      return u.name.isEmpty ? u.email : u.name;
    }

    final tutors = users.where((u) => u.role == UserRole.tutor).toList();
    // Suspended tutors (application approved, profile not) are handled in the
    // users list; this queue is people still waiting on a decision.
    final pending = tutors
        .where((t) => !t.approved && apps[t.uid]?.status != ApplicationStatus.approved)
        .toList()
      ..sort((a, b) {
        int rank(AppUser t) => switch (apps[t.uid]?.status) {
              ApplicationStatus.submitted => 0,
              ApplicationStatus.rejected => 1,
              _ => 2,
            };
        return rank(a).compareTo(rank(b));
      });
    final now = DateTime.now();
    bool needsTutor(TutoringSession s) =>
        s.tutorId == unassignedTutorId && s.status == SessionStatus.pending;

    final stats = [
      DashStat(Icons.school_rounded,
          '${users.where((u) => u.role == UserRole.student).length}', 'الطلاب', AppColors.indigo),
      DashStat(Icons.family_restroom_rounded,
          '${users.where((u) => u.role == UserRole.parent).length}', 'أولياء الأمور', AppColors.violet),
      DashStat(Icons.cast_for_education_rounded, '${tutors.where((t) => t.approved).length}',
          'معلمون معتمدون', AppColors.mint),
      DashStat(Icons.event_note_rounded, '${sessions.length}', 'إجمالي الحصص', AppColors.amber),
    ];

    // Users panel
    final q = _query.trim().toLowerCase();
    final shownUsers = users
        .where((u) => u.role == _roleTab)
        .where((u) => q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Sessions panel
    bool matches(TutoringSession s) => switch (_filter) {
          _SessionFilter.all => true,
          _SessionFilter.needsTutor => needsTutor(s),
          _SessionFilter.upcoming => s.scheduledAt.isAfter(now) &&
              (s.status == SessionStatus.pending || s.status == SessionStatus.confirmed),
          _SessionFilter.completed => s.status == SessionStatus.completed,
          _SessionFilter.cancelled => s.status == SessionStatus.cancelled,
        };
    final filtered = sessions.where(matches).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    final shownSessions = filtered.take(100).toList();
    final needsCount = sessions.where(needsTutor).length;

    const filterLabels = {
      _SessionFilter.all: 'الكل',
      _SessionFilter.needsTutor: 'تحتاج معلماً',
      _SessionFilter.upcoming: 'قادمة',
      _SessionFilter.completed: 'مكتملة',
      _SessionFilter.cancelled: 'ملغاة',
    };
    const roleLabels = {
      UserRole.tutor: 'المعلمون',
      UserRole.student: 'الطلاب',
      UserRole.parent: 'أولياء الأمور',
      UserRole.admin: 'المشرفون',
    };

    return [
      DashStats(items: stats),
      const SizedBox(height: 20),
      if (pending.isNotEmpty) ...[
        DashPanel(
          title: 'طلبات انضمام المعلمين (${pending.length})',
          child: Column(children: [
            for (final t in pending)
              _UserTile(
                user: t,
                highlight: apps[t.uid]?.status == ApplicationStatus.submitted,
                badge: _tutorBadge(t, apps[t.uid]),
                detail: _applicationDetail(apps[t.uid]),
                action: _reviewButton(t, apps[t.uid]),
              ),
          ]),
        ),
        const SizedBox(height: 20),
      ],
      DashPanel(
        title: 'الحصص',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in _SessionFilter.values)
              DashTabChip(
                f == _SessionFilter.needsTutor && needsCount > 0
                    ? '${filterLabels[f]} ($needsCount)'
                    : filterLabels[f]!,
                _filter == f,
                () => setState(() => _filter = f),
              ),
          ]),
          const SizedBox(height: 16),
          if (shownSessions.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: Text('لا توجد حصص في هذا التصنيف',
                        style: TextStyle(color: AppColors.muted))))
          else
            for (final s in shownSessions)
              _SessionRow(
                session: s,
                studentName: nameOf(s.studentId),
                tutorName: nameOf(s.tutorId),
                onAssign: needsTutor(s) ? () => _assign(s, tutors) : null,
              ),
          if (filtered.length > shownSessions.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('يتم عرض أحدث ${shownSessions.length} من ${filtered.length} حصة',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
        ]),
      ),
      const SizedBox(height: 20),
      DashPanel(
        title: 'المستخدمون',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in roleLabels.keys)
              DashTabChip(
                '${roleLabels[r]} (${users.where((u) => u.role == r).length})',
                _roleTab == r,
                () => setState(() => _roleTab = r),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو البريد',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          if (shownUsers.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: Text('لا يوجد مستخدمون',
                        style: TextStyle(color: AppColors.muted))))
          else
            for (final u in shownUsers)
              _UserTile(
                user: u,
                badge: u.role == UserRole.tutor ? _tutorBadge(u, apps[u.uid]) : null,
                action: u.role != UserRole.tutor
                    ? null
                    : u.approved
                        ? TextButton(
                            onPressed: () => _setApproved(u, false),
                            style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626)),
                            child: const Text('إيقاف'))
                        : apps[u.uid]?.status == ApplicationStatus.approved
                            ? FilledButton(
                                onPressed: () => _setApproved(u, true),
                                child: const Text('إعادة التفعيل'))
                            : _reviewButton(u, apps[u.uid]),
              ),
        ]),
      ),
    ];
  }
}

// ───────────────────────── Tiles & dialogs ─────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile(
      {required this.user, this.action, this.highlight = false, this.badge, this.detail});
  final AppUser user;
  final Widget? action;

  /// Status chip next to the name (used for tutors).
  final Widget? badge;

  /// An extra line under the email, such as an application summary.
  final String? detail;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: highlight ? AppColors.amber.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: AppColors.indigo.withValues(alpha: 0.12),
          child: Text(user.name.isEmpty ? '؟' : user.name.characters.first,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.indigo)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(user.name.isEmpty ? 'بدون اسم' : user.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge!],
            ]),
            const SizedBox(height: 2),
            Text(user.email,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
              ),
          ]),
        ),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ]),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.studentName,
    required this.tutorName,
    this.onAssign,
  });
  final TutoringSession session;
  final String studentName, tutorName;
  final VoidCallback? onAssign;

  (String, Color) get _status => switch (session.status) {
        SessionStatus.pending => ('بانتظار التأكيد', AppColors.amber),
        SessionStatus.confirmed => ('مؤكدة', AppColors.mint),
        SessionStatus.completed => ('مكتملة', AppColors.indigo),
        SessionStatus.cancelled => ('ملغاة', const Color(0xFFDC2626)),
      };

  @override
  Widget build(BuildContext context) {
    final when = session.scheduledAt.toLocal();
    final (label, color) = _status;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration:
              BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(DateFormat('d', 'ar').format(when),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(DateFormat('MMM', 'ar').format(when),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(session.subject.isEmpty ? 'حصة' : session.subject,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              if (session.isTrial) ...[
                const SizedBox(width: 8),
                const DashBadge('تجريبية', AppColors.violet),
              ],
            ]),
            const SizedBox(height: 4),
            Text('الطالب: $studentName  •  المعلم: $tutorName',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            Text(DateFormat('EEEE d MMMM • h:mm a', 'ar').format(when),
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        if (onAssign != null)
          FilledButton(
            onPressed: onAssign,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
            child: const Text('تعيين معلم'),
          )
        else
          DashBadge(label, color),
      ]),
    );
  }
}

class _TutorPickerDialog extends StatelessWidget {
  const _TutorPickerDialog({required this.tutors});
  final List<AppUser> tutors;

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('اختر المعلم', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 400,
          child: tutors.isEmpty
              ? const Text('لا يوجد معلمون معتمدون بعد. اعتمد معلماً أولاً.',
                  style: TextStyle(color: AppColors.muted))
              : ListView(shrinkWrap: true, children: [
                  for (final t in tutors)
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.indigo.withValues(alpha: 0.12),
                        child: Text(t.name.isEmpty ? '؟' : t.name.characters.first,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, color: AppColors.indigo)),
                      ),
                      title: Text(t.name.isEmpty ? t.email : t.name),
                      onTap: () => Navigator.pop(context, t.uid),
                    ),
                ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ],
      );
}
