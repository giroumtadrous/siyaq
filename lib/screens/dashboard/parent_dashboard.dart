import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/progress_report.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_widgets.dart';
import '../booking/trial_booking_screen.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  String? _selectedId;
  String _childrenKey = '';
  Stream<List<AppUser>>? _childrenStream;

  /// Re-creates the children stream only when the linked ids change, so the
  /// StreamBuilder doesn't resubscribe on every rebuild.
  Stream<List<AppUser>> _streamFor(List<String> ids) {
    final key = ids.join(',');
    if (_childrenStream == null || key != _childrenKey) {
      _childrenKey = key;
      _childrenStream = context.read<AuthService>().childrenStream(ids);
    }
    return _childrenStream!;
  }

  Future<void> _linkChild() async {
    final linked = await showDialog<bool>(
      context: context,
      builder: (_) => const _LinkChildDialog(),
    );
    if (linked == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم ربط حساب الطالب بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final me = auth.currentUser;
    final ids = me?.childIds ?? const <String>[];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: _streamFor(ids),
          builder: (context, snap) {
            final children = snap.data ?? const <AppUser>[];
            AppUser? selected;
            for (final c in children) {
              if (c.uid == _selectedId) selected = c;
            }
            selected ??= children.isEmpty ? null : children.first;

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
                          name: me?.name ?? '',
                          subtitle: 'تابع حصص أبنائك وتقدمهم الدراسي من مكان واحد.',
                          onSignOut: auth.signOut),
                      const SizedBox(height: 20),
                      if (snap.hasError)
                        const DashNotice(
                            icon: Icons.lock_outline_rounded,
                            text: 'تعذّر تحميل بيانات الأبناء. تحقق من صلاحيات قاعدة البيانات.')
                      else if (ids.isNotEmpty && !snap.hasData)
                        const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()))
                      else if (selected == null)
                        _EmptyChildren(onLink: _linkChild)
                      else ...[
                        _ChildSwitcher(
                          children: children,
                          selectedId: selected.uid,
                          onSelect: (id) => setState(() => _selectedId = id),
                          onAdd: _linkChild,
                        ),
                        const SizedBox(height: 20),
                        _ChildView(key: ValueKey(selected.uid), child: selected),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── Header / empty states ─────────────────────────

class _EmptyChildren extends StatelessWidget {
  const _EmptyChildren({required this.onLink});
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.indigo.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.family_restroom_rounded,
                size: 44, color: AppColors.indigo),
          ),
          const SizedBox(height: 20),
          const Text('اربط حساب ابنك أو ابنتك',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'اطلب من ابنك التسجيل كطالب في سياق، ثم أدخل رمز الربط الظاهر في لوحته هنا لمتابعة حصصه وتقاريره.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.8),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
              onPressed: onLink,
              icon: const Icon(Icons.link_rounded),
              label: const Text('ربط حساب طالب')),
        ]),
      );
}

class _ChildSwitcher extends StatelessWidget {
  const _ChildSwitcher({
    required this.children,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
  });
  final List<AppUser> children;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        for (final c in children)
          ChoiceChip(
            selected: c.uid == selectedId,
            onSelected: (_) => onSelect(c.uid),
            showCheckmark: false,
            avatar: CircleAvatar(
              backgroundColor:
                  c.uid == selectedId ? Colors.white : AppColors.indigo.withValues(alpha: 0.12),
              child: Text(c.name.isEmpty ? '؟' : c.name.characters.first,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.indigo)),
            ),
            label: Text(c.name.isEmpty ? c.email : c.name),
            labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: c.uid == selectedId ? Colors.white : AppColors.ink),
            selectedColor: AppColors.indigo,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ActionChip(
          onPressed: onAdd,
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: const Text('ربط طالب آخر'),
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ]);
}

// ───────────────────────── Selected child ─────────────────────────

class _ChildView extends StatefulWidget {
  const _ChildView({super.key, required this.child});
  final AppUser child;

  @override
  State<_ChildView> createState() => _ChildViewState();
}

class _ChildViewState extends State<_ChildView> {
  late final Stream<List<TutoringSession>> _sessions =
      context.read<BookingService>().sessionsForUser(widget.child.uid);
  late final Stream<List<ProgressReport>> _reports =
      context.read<ProgressService>().reportsForStudent(widget.child.uid);
  bool _showUpcoming = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TutoringSession>>(
      stream: _sessions,
      builder: (context, sessionSnap) {
        return StreamBuilder<List<ProgressReport>>(
          stream: _reports,
          builder: (context, reportSnap) {
            if (sessionSnap.hasError || reportSnap.hasError) {
              return const DashNotice(
                  icon: Icons.error_outline_rounded,
                  text: 'تعذّر تحميل البيانات. تحقق من الاتصال أو صلاحيات قاعدة البيانات.');
            }
            if (!sessionSnap.hasData || !reportSnap.hasData) {
              return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()));
            }

            final now = DateTime.now();
            final all = sessionSnap.data!;
            bool isUpcoming(TutoringSession s) =>
                s.scheduledAt.isAfter(now) &&
                s.status != SessionStatus.cancelled &&
                s.status != SessionStatus.completed;
            final upcoming = all.where(isUpcoming).toList()
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
            final past = all.where((s) => !isUpcoming(s)).toList()
              ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
            final completed =
                all.where((s) => s.status == SessionStatus.completed).length;
            final reports = reportSnap.data!;
            final avg = reports.isEmpty
                ? null
                : reports.map((r) => r.score).reduce((a, b) => a + b) / reports.length;

            final list = _showUpcoming ? upcoming : past;

            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DashStats(items: [
                DashStat(Icons.event_rounded, '${upcoming.length}', 'حصص قادمة', AppColors.indigo),
                DashStat(Icons.check_circle_rounded, '$completed', 'حصص مكتملة', AppColors.mint),
                DashStat(Icons.trending_up_rounded, avg == null ? '—' : '${avg.round()}%',
                    'متوسط التقدم', AppColors.amber),
              ]),
              const SizedBox(height: 20),
              if (upcoming.isNotEmpty) ...[
                _NextSession(session: upcoming.first),
                const SizedBox(height: 20),
              ],
              DashPanel(
                title: 'حصص ${widget.child.name}',
                trailing: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TrialBookingScreen(
                          studentId: widget.child.uid, studentName: widget.child.name))),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('حجز حصة تجريبية'),
                ),
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
                          child: Text(
                              _showUpcoming ? 'لا توجد حصص قادمة' : 'لا توجد حصص سابقة',
                              style: const TextStyle(color: AppColors.muted))),
                    )
                  else
                    for (final s in list) _SessionTile(session: s),
                ]),
              ),
              const SizedBox(height: 20),
              DashPanel(
                title: 'تقارير التقدم',
                child: reports.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                            child: Text('ستظهر تقارير المعلم هنا بعد أول حصة',
                                style: TextStyle(color: AppColors.muted))))
                    : Column(children: [for (final r in reports) _ReportTile(report: r)]),
              ),
            ]);
          },
        );
      },
    );
  }
}

class _NextSession extends StatelessWidget {
  const _NextSession({required this.session});
  final TutoringSession session;

  @override
  Widget build(BuildContext context) {
    final when = session.scheduledAt.toLocal();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الحصة القادمة',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 6),
            Text(session.subject.isEmpty ? 'حصة' : session.subject,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE d MMMM • h:mm a', 'ar').format(when),
                style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        if (session.googleMeetLink != null && session.googleMeetLink!.isNotEmpty)
          FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse(session.googleMeetLink!)),
            icon: const Icon(Icons.video_call_rounded),
            label: const Text('انضمام'),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: AppColors.ink),
          )
        else
          const Text('الرابط قيد الإضافة',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
      ]),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final TutoringSession session;

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
    final canJoin = session.googleMeetLink != null &&
        session.googleMeetLink!.isNotEmpty &&
        session.status == SessionStatus.confirmed &&
        session.scheduledAt.isAfter(DateTime.now().subtract(const Duration(hours: 2)));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
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
            Text(DateFormat('EEEE • h:mm a', 'ar').format(when),
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        DashBadge(label, color),
        if (canJoin)
          IconButton(
            tooltip: 'فتح Google Meet',
            onPressed: () => launchUrl(Uri.parse(session.googleMeetLink!)),
            icon: const Icon(Icons.video_call_rounded, color: AppColors.indigo),
          ),
      ]),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});
  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final color = report.score >= 80
        ? AppColors.mint
        : report.score >= 50
            ? AppColors.amber
            : const Color(0xFFDC2626);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(report.subject,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text(DateFormat('d MMMM y', 'ar').format(report.date),
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: report.score / 100,
                minHeight: 8,
                color: color,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${report.score.round()}%',
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ]),
        if (report.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(report.notes,
              style: const TextStyle(color: AppColors.muted, height: 1.7)),
        ],
      ]),
    );
  }
}

// ───────────────────────── Link-child dialog ─────────────────────────

class _LinkChildDialog extends StatefulWidget {
  const _LinkChildDialog();

  @override
  State<_LinkChildDialog> createState() => _LinkChildDialogState();
}

class _LinkChildDialogState extends State<_LinkChildDialog> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length < 20) {
      setState(() => _error = 'أدخل رمز الربط كاملاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().linkChildByCode(code);
      if (mounted) Navigator.of(context).pop(true);
    } on ChildLinkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الربط، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('ربط حساب طالب',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('أدخل رمز الربط الذي يظهر في لوحة ابنك بعد تسجيل الدخول كطالب.',
                style: TextStyle(color: AppColors.muted, height: 1.7)),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'رمز الربط',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                errorText: _error,
                errorMaxLines: 3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(false),
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
                : const Text('ربط'),
          ),
        ],
      );
}
