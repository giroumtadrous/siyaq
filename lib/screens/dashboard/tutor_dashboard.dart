import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_widgets.dart';

class TutorDashboard extends StatefulWidget {
  const TutorDashboard({super.key});

  @override
  State<TutorDashboard> createState() => _TutorDashboardState();
}

class _TutorDashboardState extends State<TutorDashboard> {
  late final String _uid = context.read<AuthService>().currentUser?.uid ?? '';
  late final Stream<List<TutoringSession>> _mine =
      context.read<BookingService>().sessionsForUser(_uid, asTutor: true);
  late final Stream<List<TutoringSession>> _open =
      context.read<BookingService>().unassignedSessions();

  bool _showUpcoming = true;
  String _namesKey = '';
  Stream<List<AppUser>>? _namesStream;

  /// Student-name lookup, re-created only when the set of students changes.
  Stream<List<AppUser>> _namesFor(Iterable<String> ids) {
    final key = (ids.toSet().toList()..sort()).join(',');
    if (_namesStream == null || key != _namesKey) {
      _namesKey = key;
      _namesStream = context.read<AuthService>().usersStream(ids);
    }
    return _namesStream!;
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    try {
      await action();
      if (ok != null && mounted) _toast(ok);
    } on SessionTakenException {
      if (mounted) _toast('تم قبول هذه الحصة من معلم آخر');
    } catch (_) {
      if (mounted) _toast('تعذّر تنفيذ العملية، حاول مرة أخرى');
    }
  }

  Future<void> _accept(TutoringSession s) async {
    final link = await showDialog<String>(
      context: context,
      builder: (_) => const _MeetLinkDialog(title: 'قبول الحصة', optional: true),
    );
    if (link == null || !mounted) return;
    await _run(
      () => context.read<BookingService>().acceptSession(
            sessionId: s.id,
            tutorId: _uid,
            googleMeetLink: link.isEmpty ? null : link,
          ),
      ok: 'تم قبول الحصة وتأكيدها',
    );
  }

  Future<void> _editLink(TutoringSession s) async {
    final link = await showDialog<String>(
      context: context,
      builder: (_) => _MeetLinkDialog(
          title: 'رابط Google Meet', initial: s.googleMeetLink ?? ''),
    );
    if (link == null || !mounted) return;
    await _run(
      () => context.read<BookingService>().updateSession(s.id, googleMeetLink: link),
      ok: 'تم حفظ الرابط',
    );
  }

  Future<void> _setStatus(TutoringSession s, SessionStatus status, String ok,
      {String? confirm}) async {
    if (confirm != null) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(confirm),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    await _run(
      () => context.read<BookingService>().updateSession(s.id, status: status),
      ok: ok,
    );
  }

  Future<void> _writeReport(TutoringSession s, String studentName) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ReportDialog(
          tutorId: _uid, studentId: s.studentId, studentName: studentName, subject: s.subject),
    );
    if (saved == true && mounted) _toast('تم إرسال التقرير إلى ولي الأمر والطالب');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: StreamBuilder<List<TutoringSession>>(
          stream: _mine,
          builder: (context, mineSnap) => StreamBuilder<List<TutoringSession>>(
            stream: _open,
            builder: (context, openSnap) {
              final mine = mineSnap.data ?? const <TutoringSession>[];
              final open = (openSnap.data ?? const <TutoringSession>[])
                  .where((s) => s.scheduledAt.isAfter(DateTime.now()))
                  .toList();
              final ids = [...mine, ...open].map((s) => s.studentId);

              return StreamBuilder<List<AppUser>>(
                stream: _namesFor(ids),
                builder: (context, namesSnap) {
                  final names = {
                    for (final u in namesSnap.data ?? const <AppUser>[])
                      u.uid: u.name.isEmpty ? u.email : u.name
                  };
                  String nameOf(String id) => names[id] ?? 'طالب';

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
                              subtitle: 'أدر حصصك، تواصل مع طلابك، واكتب تقارير التقدم.',
                              onSignOut: auth.signOut,
                            ),
                            const SizedBox(height: 20),
                            if (mineSnap.hasError || openSnap.hasError)
                              const DashNotice(
                                  icon: Icons.error_outline_rounded,
                                  text:
                                      'تعذّر تحميل الحصص. تحقق من الاتصال أو صلاحيات قاعدة البيانات.')
                            else if (!mineSnap.hasData || !openSnap.hasData)
                              const Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Center(child: CircularProgressIndicator()))
                            else
                              ..._content(mine, open, nameOf),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _content(List<TutoringSession> mine, List<TutoringSession> open,
      String Function(String) nameOf) {
    final now = DateTime.now();
    bool isUpcoming(TutoringSession s) =>
        s.scheduledAt.isAfter(now.subtract(const Duration(hours: 2))) &&
        (s.status == SessionStatus.pending || s.status == SessionStatus.confirmed);

    final upcoming = mine.where(isUpcoming).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final past = mine.where((s) => !isUpcoming(s)).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    final today = mine.where((s) =>
        s.status != SessionStatus.cancelled &&
        s.scheduledAt.year == now.year &&
        s.scheduledAt.month == now.month &&
        s.scheduledAt.day == now.day);
    final completed = mine.where((s) => s.status == SessionStatus.completed).length;
    final students = mine.map((s) => s.studentId).toSet().length;
    final list = _showUpcoming ? upcoming : past;

    return [
      DashStats(items: [
        DashStat(Icons.today_rounded, '${today.length}', 'حصص اليوم', AppColors.indigo),
        DashStat(Icons.event_rounded, '${upcoming.length}', 'حصص قادمة', AppColors.violet),
        DashStat(Icons.check_circle_rounded, '$completed', 'حصص مكتملة', AppColors.mint),
        DashStat(Icons.groups_rounded, '$students', 'طلابي', AppColors.amber),
      ]),
      const SizedBox(height: 20),
      if (open.isNotEmpty) ...[
        DashPanel(
          title: 'طلبات حصص جديدة (${open.length})',
          child: Column(children: [
            for (final s in open)
              _RequestTile(
                  session: s, studentName: nameOf(s.studentId), onAccept: () => _accept(s)),
          ]),
        ),
        const SizedBox(height: 20),
      ],
      DashPanel(
        title: 'جدول حصصي',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, children: [
            DashTabChip('القادمة (${upcoming.length})', _showUpcoming,
                () => setState(() => _showUpcoming = true)),
            DashTabChip('السابقة (${past.length})', !_showUpcoming,
                () => setState(() => _showUpcoming = false)),
          ]),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text(_showUpcoming ? 'لا توجد حصص قادمة' : 'لا توجد حصص سابقة',
                      style: const TextStyle(color: AppColors.muted))),
            )
          else
            for (final s in list)
              _SessionTile(
                session: s,
                studentName: nameOf(s.studentId),
                onConfirm: () => _setStatus(s, SessionStatus.confirmed, 'تم تأكيد الحصة'),
                onCancel: () => _setStatus(s, SessionStatus.cancelled, 'تم إلغاء الحصة',
                    confirm: 'هل تريد إلغاء هذه الحصة؟'),
                onComplete: () => _setStatus(s, SessionStatus.completed, 'تم تسجيل الحصة كمكتملة'),
                onEditLink: () => _editLink(s),
                onReport: () => _writeReport(s, nameOf(s.studentId)),
              ),
        ]),
      ),
    ];
  }
}

// ───────────────────────── Tiles ─────────────────────────

class _DateBlock extends StatelessWidget {
  const _DateBlock(this.when);
  final DateTime when;

  @override
  Widget build(BuildContext context) => Container(
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
      );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(
      {required this.session, required this.studentName, required this.onAccept});
  final TutoringSession session;
  final String studentName;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final when = session.scheduledAt.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        _DateBlock(when),
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
            Text('$studentName • ${DateFormat('EEEE d MMMM', 'ar').format(when)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onAccept,
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          child: const Text('قبول'),
        ),
      ]),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.studentName,
    required this.onConfirm,
    required this.onCancel,
    required this.onComplete,
    required this.onEditLink,
    required this.onReport,
  });
  final TutoringSession session;
  final String studentName;
  final VoidCallback onConfirm, onCancel, onComplete, onEditLink, onReport;

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
    final link = session.googleMeetLink;
    final hasLink = link != null && link.isNotEmpty;
    final s = session.status;

    Widget action(String text, IconData icon, VoidCallback onTap, {Color? color}) =>
        TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(text),
          style: TextButton.styleFrom(foregroundColor: color ?? AppColors.indigo),
        );

    final actions = <Widget>[
      if (s == SessionStatus.pending) action('تأكيد', Icons.check_rounded, onConfirm),
      if (s == SessionStatus.pending || s == SessionStatus.confirmed) ...[
        action(hasLink ? 'تعديل الرابط' : 'إضافة رابط Meet', Icons.link_rounded, onEditLink),
        if (hasLink)
          action('انضمام', Icons.video_call_rounded, () => launchUrl(Uri.parse(link))),
      ],
      if (s == SessionStatus.confirmed)
        action('تمت الحصة', Icons.task_alt_rounded, onComplete, color: AppColors.mint),
      if (s == SessionStatus.completed)
        action('كتابة تقرير', Icons.edit_note_rounded, onReport),
      if (s == SessionStatus.pending || s == SessionStatus.confirmed)
        action('إلغاء', Icons.close_rounded, onCancel, color: const Color(0xFFDC2626)),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _DateBlock(when),
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
              Text('$studentName • ${DateFormat('EEEE • h:mm a', 'ar').format(when)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          DashBadge(label, color),
        ]),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 0, children: actions),
        ],
      ]),
    );
  }
}

// ───────────────────────── Dialogs ─────────────────────────

class _MeetLinkDialog extends StatefulWidget {
  const _MeetLinkDialog({required this.title, this.initial = '', this.optional = false});
  final String title;
  final String initial;

  /// When true an empty link is allowed (it can be added later).
  final bool optional;

  @override
  State<_MeetLinkDialog> createState() => _MeetLinkDialogState();
}

class _MeetLinkDialogState extends State<_MeetLinkDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty && widget.optional) return Navigator.pop(context, '');
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _error = 'أدخل رابطاً صحيحاً يبدأ بـ https://');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.optional ? 'رابط Google Meet (اختياري)' : 'رابط Google Meet',
              hintText: 'https://meet.google.com/...',
              prefixIcon: const Icon(Icons.link_rounded),
              errorText: _error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            child: Text(widget.optional ? 'قبول' : 'حفظ'),
          ),
        ],
      );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.tutorId,
    required this.studentId,
    required this.studentName,
    required this.subject,
  });
  final String tutorId, studentId, studentName, subject;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  late final _subject = TextEditingController(text: widget.subject);
  final _notes = TextEditingController();
  double _score = 70;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'أدخل المادة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<ProgressService>().addReport(
            studentId: widget.studentId,
            tutorId: widget.tutorId,
            subject: _subject.text.trim(),
            score: _score,
            notes: _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذّر حفظ التقرير، حاول مرة أخرى';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('تقرير ${widget.studentName}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: _subject,
                decoration: InputDecoration(
                  labelText: 'المادة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Text('مستوى التقدم', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_score.round()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.indigo)),
              ]),
              Slider(
                value: _score,
                max: 100,
                divisions: 20,
                label: '${_score.round()}%',
                onChanged: (v) => setState(() => _score = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'ملاحظات المعلم',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('إرسال التقرير'),
          ),
        ],
      );
}
