import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../data/curriculum.dart';
import '../../models/tutor_application.dart';
import '../../services/auth_service.dart';
import '../../services/tutor_application_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_widgets.dart';
import 'tutor_application_form.dart';

/// What a tutor sees until an admin approves them: the application form, then
/// its status. Once approved, AuthGate swaps this for the tutor dashboard.
class TutorApplicationScreen extends StatefulWidget {
  const TutorApplicationScreen({super.key});

  @override
  State<TutorApplicationScreen> createState() => _TutorApplicationScreenState();
}

class _TutorApplicationScreenState extends State<TutorApplicationScreen> {
  late final String _uid = context.read<AuthService>().currentUser?.uid ?? '';
  late final Stream<TutorApplication?> _application =
      context.read<TutorApplicationService>().watch(_uid);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profileApproved = auth.currentUser?.approved == true;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: StreamBuilder<TutorApplication?>(
          stream: _application,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final app = snap.data;

            // Which step the tracker is on, and what to say about it.
            final suspended = app?.status == ApplicationStatus.approved && !profileApproved;
            final (step, title, subtitle) = switch (app?.status) {
              null => (0, 'أكمل طلب الانضمام', 'نراجع بياناتك ومؤهلاتك قبل تفعيل حساب المعلم.'),
              ApplicationStatus.rejected => (
                  0,
                  'نحتاج منك تعديلاً',
                  'راجع ملاحظة الإدارة أدناه، ثم عدّل طلبك وأعد إرساله.'
                ),
              ApplicationStatus.submitted => (
                  1,
                  'طلبك قيد المراجعة',
                  'سيصلك القرار هنا، ولا حاجة لأي إجراء الآن.'
                ),
              ApplicationStatus.approved => suspended
                  ? (2, 'الحساب موقوف', 'تواصل مع إدارة المنصة لمعرفة السبب.')
                  : (2, 'تم اعتماد حسابك', 'جارٍ فتح لوحتك…'),
            };

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width >= 900 ? 40 : 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _TopBar(onSignOut: auth.signOut),
                    const SizedBox(height: 24),
                    if (!loading && !snap.hasError) ...[
                      ApplicationTracker(step: step),
                      const SizedBox(height: 24),
                    ],
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(title,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(color: AppColors.muted, height: 1.6)),
                    const SizedBox(height: 16),
                    if (snap.hasError)
                      const DashNotice(
                          icon: Icons.error_outline_rounded,
                          text: 'تعذّر تحميل طلبك. تحقق من الاتصال ثم أعد فتح الصفحة.')
                    else if (loading)
                      const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()))
                    else if (app == null || app.status == ApplicationStatus.rejected) ...[
                      if (app?.reviewNote != null) _RejectionNote(note: app!.reviewNote!),
                      TutorApplicationForm(
                        // A rejected tutor edits their previous answers.
                        key: ValueKey(app?.submittedAt),
                        initial: app,
                        onSubmit: (draft) =>
                            context.read<TutorApplicationService>().submit(_uid, draft),
                      ),
                    ] else if (app.status == ApplicationStatus.submitted)
                      _SubmittedSummary(app: app),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
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
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        const Text('سياق', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const Spacer(),
        IconButton(
            onPressed: onSignOut,
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded)),
      ]);
}

/// Application → review → approval. A real sequence, so numbering is honest.
class ApplicationTracker extends StatelessWidget {
  const ApplicationTracker({super.key, required this.step});

  /// 0 = apply, 1 = in review, 2 = approved.
  final int step;

  static const _labels = ['تقديم الطلب', 'المراجعة', 'الاعتماد'];

  @override
  Widget build(BuildContext context) {
    Widget dot(int i) {
      final done = i < step;
      final current = i == step;
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done || current ? AppColors.indigo : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: done || current ? AppColors.indigo : AppColors.border, width: 2),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : Text('${i + 1}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: current ? Colors.white : AppColors.muted)),
      );
    }

    Widget line(int i) => Expanded(
          child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 22),
              color: i < step ? AppColors.indigo : AppColors.border),
        );

    return Semantics(
      container: true,
      label: 'الخطوة ${step + 1} من 3: ${_labels[step]}',
      excludeSemantics: true,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < 3; i++) ...[
          Column(children: [
            dot(i),
            const SizedBox(height: 6),
            Text(_labels[i],
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == step ? FontWeight.w800 : FontWeight.w500,
                    color: i == step ? AppColors.ink : AppColors.muted)),
          ]),
          if (i < 2) line(i),
        ],
      ]),
    );
  }
}

class _RejectionNote extends StatelessWidget {
  const _RejectionNote({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB91C1C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ملاحظة الإدارة',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7F1D1D))),
              const SizedBox(height: 4),
              Text(note, style: const TextStyle(color: Color(0xFF7F1D1D), height: 1.7)),
            ]),
          ),
        ]),
      );
}

/// Read-only recap of what was submitted, shown while the application waits.
class _SubmittedSummary extends StatelessWidget {
  const _SubmittedSummary({required this.app});
  final TutorApplication app;

  @override
  Widget build(BuildContext context) {
    final stageNames = [
      for (final s in stages)
        if (app.stages.contains(s.id)) s.name,
    ];
    Widget row(String label, String value, {bool ltr = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value,
                textDirection: ltr ? TextDirection.ltr : null,
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
          ]),
        );

    return DashPanel(
      title: 'ما أرسلته',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('أُرسل في ${DateFormat('d MMMM y', 'ar').format(app.submittedAt)}',
            style: const TextStyle(color: AppColors.muted)),
        const Divider(height: 24, color: AppColors.border),
        row('الهاتف', app.phone, ltr: true),
        row('المؤهل العلمي', app.qualification),
        row('سنوات الخبرة', '${app.experienceYears}'),
        row('المراحل', stageNames.join('، ')),
        row('المواد', app.subjects.join('، ')),
        row('الأوقات المناسبة', app.availability),
        row('النبذة', app.bio),
      ]),
    );
  }
}
