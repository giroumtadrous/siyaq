import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/curriculum.dart';
import '../../models/tutor_profile.dart';
import '../../services/tutor_directory_service.dart';
import '../../services/tutor_ranking.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_widgets.dart';
import '../dashboard/student/next_class_card.dart' show arabicNumber;
import 'tutor_widgets.dart';

/// The subjects taught in [stage], or in one [grade] of it, in curriculum order.
List<Subject> subjectsFor(Stage stage, [Grade? grade]) {
  final seen = <String>{};
  return [
    for (final g in grade == null ? stage.grades : [grade])
      for (final s in g.subjects)
        if (seen.add(s.name)) s,
  ];
}

/// Tutors who teach [stage], one ranked group per subject (best first).
/// Narrowed to one [grade], one [subject] and names containing [query].
/// Subjects with no matching tutor are left out.
List<(Subject, List<TutorProfile>)> groupTutors(
  Iterable<TutorProfile> tutors, {
  required Stage stage,
  Grade? grade,
  Subject? subject,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final matching =
      tutors.where((t) => t.active && (q.isEmpty || t.name.toLowerCase().contains(q))).toList();
  return [
    for (final s in subject == null ? subjectsFor(stage, grade) : [subject])
      (s, rankTutors(matching.where((t) => t.teaches(stageId: stage.id, subject: s.name))))
  ].where((g) => g.$2.isNotEmpty).toList();
}

/// Students browse approved tutors by school year (stage, then grade) and
/// subject, ranked best first within each subject.
class TutorDirectoryScreen extends StatefulWidget {
  const TutorDirectoryScreen({super.key, this.tutors});

  /// Overrides the Firestore stream (for tests).
  final Stream<List<TutorProfile>>? tutors;

  @override
  State<TutorDirectoryScreen> createState() => _TutorDirectoryScreenState();
}

class _TutorDirectoryScreenState extends State<TutorDirectoryScreen> {
  late final Stream<List<TutorProfile>> _tutors =
      widget.tutors ?? context.read<TutorDirectoryService>().activeTutors();

  Stage _stage = stages.first;
  Grade? _grade;
  Subject? _subject;
  String _query = '';

  void _pickStage(Stage s) => setState(() {
        _stage = s;
        _grade = null;
        _subject = null;
      });

  void _pickGrade(Grade? g) => setState(() {
        _grade = g;
        // Keep the subject only if the new year still teaches it.
        if (_subject != null &&
            !subjectsFor(_stage, g).any((s) => s.name == _subject!.name)) {
          _subject = null;
        }
      });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('ابحث عن معلم', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'كيف نرتّب المعلمين؟',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showDialog<void>(
                context: context, builder: (_) => const _RankingExplainer()),
          ),
        ],
      ),
      body: StreamBuilder<List<TutorProfile>>(
        stream: _tutors,
        builder: (context, snap) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _filters(),
                const SizedBox(height: 20),
                if (snap.hasError)
                  const DashNotice(
                      icon: Icons.error_outline_rounded,
                      text: 'تعذّر تحميل المعلمين. تحقق من الاتصال ثم حاول مرة أخرى.')
                else if (!snap.hasData)
                  const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()))
                else
                  ..._results(snap.data!),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        );

    return DashPanel(
      title: 'الصف والمادة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'ابحث باسم المعلم',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        label('المرحلة'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in stages) DashTabChip(s.name, _stage.id == s.id, () => _pickStage(s)),
        ]),
        label('الصف'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DashTabChip('كل الصفوف', _grade == null, () => _pickGrade(null)),
          for (final g in _stage.grades)
            DashTabChip(g.name, _grade?.name == g.name, () => _pickGrade(g)),
        ]),
        label('المادة'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DashTabChip('كل المواد', _subject == null, () => setState(() => _subject = null)),
          for (final s in subjectsFor(_stage, _grade))
            DashTabChip(s.name, _subject?.name == s.name, () => setState(() => _subject = s)),
        ]),
      ]),
    );
  }

  List<Widget> _results(List<TutorProfile> tutors) {
    final groups = groupTutors(tutors,
        stage: _stage, grade: _grade, subject: _subject, query: _query);
    if (groups.isEmpty) {
      return [
        DashNotice(
          icon: Icons.person_search_rounded,
          text: _query.trim().isNotEmpty
              ? 'لا يوجد معلم بهذا الاسم في هذا الصف والمادة.'
              : 'لا يوجد معلمون متاحون لهذا الاختيار بعد. جرّب مادة أو صفاً آخر.',
        ),
      ];
    }
    return [
      for (final (subject, ranked) in groups) ...[
        DashPanel(
          title: subject.name,
          trailing: Text('${arabicNumber(ranked.length)} معلم',
              style: const TextStyle(color: AppColors.muted)),
          child: Column(children: [
            for (var i = 0; i < ranked.length; i++)
              TutorCard(
                tutor: ranked[i],
                rank: i + 1,
                onTap: () => showTutorDetails(context, ranked[i]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }
}

class _RankingExplainer extends StatelessWidget {
  const _RankingExplainer();

  @override
  Widget build(BuildContext context) {
    Widget line(String weight, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 44,
                child: Text(weight,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.indigo))),
            Expanded(child: Text(text, style: const TextStyle(height: 1.6))),
          ]),
        );
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('كيف نرتّب المعلمين؟', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          line('٥٠٪', 'تقييمات الطلاب. المعلم الجديد يبدأ من تقييم متوسط حتى تتراكم تقييماته، '
              'فلا يتصدر أحد بتقييم واحد.'),
          line('٢٠٪', 'عدد الحصص المكتملة على المنصة.'),
          line('١٥٪', 'الالتزام: نسبة الحصص التي أكملها المعلم ولم يلغِها.'),
          line('١٥٪', 'سنوات الخبرة في التدريس.'),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
      ],
    );
  }
}
