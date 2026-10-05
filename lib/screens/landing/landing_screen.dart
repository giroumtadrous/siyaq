import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/curriculum.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_screen.dart';

bool _isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 900;

Future<void> _openWhatsapp(String message) => launchUrl(
      Uri.https('wa.me', '/$whatsappNumber', {'text': message}),
      mode: LaunchMode.externalApplication,
    );

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _curriculumKey = GlobalKey();

  void _scrollToCurriculum() => Scrollable.ensureVisible(
        _curriculumKey.currentContext!,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(onBrowse: _scrollToCurriculum),
            const _Features(),
            CurriculumExplorer(key: _curriculumKey),
            const _Steps(),
            _Footer(onBrowse: _scrollToCurriculum),
          ],
        ),
      ),
    );
  }
}

/// Constrains content to a readable width with responsive side padding.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.color, this.vertical = 72});
  final Widget child;
  final Color? color;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: EdgeInsets.symmetric(
          horizontal: _isWide(context) ? 48 : 20, vertical: vertical),
      child: Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180), child: child),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: light ? null : AppColors.brandGradient,
          color: light ? Colors.white : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('س',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: light ? AppColors.indigo : Colors.white)),
      ),
      const SizedBox(width: 10),
      Text('سياق',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: light ? Colors.white : AppColors.ink)),
    ]);
  }
}

// ───────────────────────── Hero ─────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final text = Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const _Pill('فصول تفاعلية مباشرة • حصة أولى مجانية'),
        const SizedBox(height: 24),
        Text('التعليم الخصوصي المعتمد',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: TextStyle(
                fontSize: wide ? 54 : 34, fontWeight: FontWeight.w800, height: 1.25)),
        ShaderMask(
          shaderCallback: (r) => AppColors.brandGradient.createShader(r),
          child: Text('في فصول تفاعلية مباشرة',
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                  fontSize: wide ? 54 : 34,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: Colors.white)),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'نخبة من أفضل المعلمين المعتمدين والمفحوصين تربوياً في القرآن الكريم '
            'واللغة العربية والمواد الدراسية، مع حصة تجريبية مجانية ومتابعة مستمرة '
            'لمستوى أبنائك.',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: const TextStyle(
                fontSize: 17, height: 1.9, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.arrow_downward_rounded),
              label: const Text('تصفح المناهج والمعلمين')),
          OutlinedButton(
            onPressed: () => _openWhatsapp('مرحباً، أود حجز حصة تجريبية مجانية'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              side: const BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('احجز عبر واتساب',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 36),
        const Wrap(spacing: 28, runSpacing: 12, children: [
          _MiniStat(Icons.star_rounded, '4.9/5', 'تقييم أولياء الأمور', AppColors.amber),
          _MiniStat(Icons.verified_rounded, '100%', 'معلمون مفحوصون تربوياً', AppColors.mint),
        ]),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF1F0FF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(children: [
        _Section(
          vertical: 20,
          child: Row(children: [
            const _Logo(),
            const Spacer(),
            if (wide)
              TextButton(onPressed: onBrowse, child: const Text('المناهج')),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AuthScreen())),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('تسجيل الدخول'),
            ),
          ]),
        ),
        _Section(
          vertical: wide ? 56 : 32,
          child: wide
              ? Row(children: [
                  Expanded(flex: 6, child: text),
                  const SizedBox(width: 48),
                  const Expanded(flex: 5, child: _HeroCard()),
                ])
              : Column(children: [text, const SizedBox(height: 40), const _HeroCard()]),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.indigo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.indigo, fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      ]);
}

/// Decorative "live class" mock-up for the hero.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Container(
        height: 360,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: AppColors.indigo.withValues(alpha: 0.3),
                blurRadius: 50,
                offset: const Offset(0, 24))
          ],
        ),
        child: Stack(children: [
          Positioned(
              top: -40,
              left: -40,
              child: CircleAvatar(
                  radius: 100, backgroundColor: Colors.white.withValues(alpha: 0.08))),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(99)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.circle, color: Color(0xFF4ADE80), size: 10),
                          SizedBox(width: 6),
                          Text('بث مباشر',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    const Text('حلقة التجويد',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('أحكام النون الساكنة والتنوين',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 28),
                    Row(children: [
                      for (final i in [0, 1, 2])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 10),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white.withValues(alpha: 0.2 + i * 0.1),
                            child: const Icon(Icons.person_rounded, color: Colors.white),
                          ),
                        ),
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
      PositionedDirectional(
        bottom: -22,
        start: -12,
        child: _FloatingNote(
            icon: Icons.assignment_turned_in_rounded,
            color: AppColors.mint,
            title: 'تقرير بعد كل حصة',
            sub: 'متابعة واضحة للمستوى'),
      ),
    ]);
  }
}

class _FloatingNote extends StatelessWidget {
  const _FloatingNote(
      {required this.icon, required this.color, required this.title, required this.sub});
  final IconData icon;
  final Color color;
  final String title, sub;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ]),
      );
}

// ───────────────────────── Features ─────────────────────────

class _Features extends StatelessWidget {
  const _Features();

  static const _items = [
    (Icons.insights_rounded, 'تقارير دورية لمتابعة المستوى',
        'تقارير أكاديمية واضحة ومستمرة بعد كل حصة ترصد التطور الحقيقي للطالب والواجبات المطلوبة.', AppColors.indigo),
    (Icons.card_giftcard_rounded, 'حصة أولى تجريبية مجانية',
        'جرّب أسلوب الشرح والتفاعل مع المعلم بنفسك وبدون أي التزام مالي أو دفع مسبق.', AppColors.mint),
    (Icons.workspace_premium_rounded, 'نخبة من المعلمين المعتمدين',
        'فحص شامل ودقيق للمؤهلات التربوية، الإجازات العلمية، وسنوات الخبرة العملية.', AppColors.violet),
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      vertical: 40,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 800 ? 3 : 1;
        final w = (c.maxWidth - (cols - 1) * 20) / cols;
        return Wrap(spacing: 20, runSpacing: 20, children: [
          for (final f in _items)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: f.$4.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(f.$1, color: f.$4, size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text(f.$2,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(f.$3,
                      style: const TextStyle(color: AppColors.muted, height: 1.8)),
                ]),
              ),
            ),
        ]);
      }),
    );
  }
}

// ───────────────────────── Curriculum explorer ─────────────────────────

class CurriculumExplorer extends StatefulWidget {
  const CurriculumExplorer({super.key});

  @override
  State<CurriculumExplorer> createState() => _CurriculumExplorerState();
}

class _CurriculumExplorerState extends State<CurriculumExplorer> {
  int _stage = 1;
  int? _grade;
  Subject? _subject;

  Stage get _currentStage => stages[_stage];

  @override
  Widget build(BuildContext context) {
    final grade = _grade == null ? null : _currentStage.grades[_grade!];
    return _Section(
      color: AppColors.surface,
      child: Column(children: [
        const _Pill('استعراض المناهج الدراسية'),
        const SizedBox(height: 16),
        const Text('اختر المرحلة والصف',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text(
          'حدد المرحلة والصف الدراسي، ثم اضغط على المادة ليظهر لك المعلمون المتاحون للحجز المباشر عبر واتساب.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.8, fontSize: 16),
        ),
        const SizedBox(height: 32),
        _StageTabs(
          selected: _stage,
          onChanged: (i) => setState(() {
            _stage = i;
            _grade = null;
            _subject = null;
          }),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
          final w = (c.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (final (i, g) in _currentStage.grades.indexed)
              SizedBox(
                width: w,
                child: _GradeCard(
                  index: i + 1,
                  grade: g,
                  selected: _grade == i,
                  onTap: () => setState(() {
                    _grade = i;
                    _subject = null;
                  }),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: grade == null
              ? const _Hint(key: ValueKey('hint'))
              : _SubjectPanel(
                  key: ValueKey(grade.name),
                  grade: grade,
                  selected: _subject,
                  onSelect: (s) => setState(() => _subject = s),
                ),
        ),
      ]),
    );
  }
}

class _StageTabs extends StatelessWidget {
  const _StageTabs({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)),
        child: Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: [
          for (final (i, s) in stages.indexed)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  gradient: i == selected ? AppColors.brandGradient : null,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(s.icon,
                      size: 20, color: i == selected ? Colors.white : AppColors.muted),
                  const SizedBox(width: 8),
                  Text(s.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: i == selected ? Colors.white : AppColors.ink)),
                ]),
              ),
            ),
        ]),
      );
}

class _GradeCard extends StatelessWidget {
  const _GradeCard(
      {required this.index, required this.grade, required this.selected, required this.onTap});
  final int index;
  final Grade grade;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: selected ? AppColors.indigo : AppColors.border,
                width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppColors.indigo.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 10))
                  ]
                : null,
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.brandGradient : null,
                color: selected ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('$index',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: selected ? Colors.white : AppColors.indigo)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(grade.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(grade.description,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 13, height: 1.6)),
              ]),
            ),
          ]),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.5)),
        child: const Column(children: [
          Icon(Icons.touch_app_rounded, size: 36, color: AppColors.indigo),
          SizedBox(height: 10),
          Text('اختر الصف والمادة لعرض المعلمين المتاحين',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          SizedBox(height: 6),
          Text('انقر على أي صف بالأعلى ثم اختر المادة المطلوبة.',
              style: TextStyle(color: AppColors.muted)),
        ]),
      );
}

class _SubjectPanel extends StatelessWidget {
  const _SubjectPanel({super.key, required this.grade, required this.selected, required this.onSelect});
  final Grade grade;
  final Subject? selected;
  final ValueChanged<Subject> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المواد المتاحة في ${grade.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final s in grade.subjects)
              ChoiceChip(
                selected: selected == s,
                onSelected: (_) => onSelect(s),
                showCheckmark: false,
                avatar: Icon(s.icon,
                    size: 18, color: selected == s ? Colors.white : AppColors.indigo),
                label: Text(s.name),
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected == s ? Colors.white : AppColors.ink),
                selectedColor: AppColors.indigo,
                backgroundColor: AppColors.surface,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
          ]),
          if (selected != null) ...[
            const Divider(height: 36, color: AppColors.border),
            Text(selected!.description,
                style: const TextStyle(color: AppColors.muted, height: 1.7)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openWhatsapp(
                  'مرحباً، أود حجز حصة تجريبية مجانية في ${selected!.name} - ${grade.name}'),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('احجز حصتك التجريبية مجاناً'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            ),
          ],
        ]),
      );
}

// ───────────────────────── Steps ─────────────────────────

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('حدد الصف الدراسي', 'اختر المرحلة والصف المناسبين لطفلك.'),
      ('اضغط على المادة', 'استعرض المواد والمعلمين المتاحين فوراً.'),
      ('احجز حصتك التجريبية مجاناً', 'تواصل معنا عبر واتساب وابدأ بدون أي التزام.'),
    ];
    return _Section(
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 800 ? 3 : 1;
        final w = (c.maxWidth - (cols - 1) * 24) / cols;
        return Wrap(spacing: 24, runSpacing: 24, children: [
          for (final (i, s) in steps.indexed)
            SizedBox(
              width: w,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.$1,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(s.$2,
                        style: const TextStyle(color: AppColors.muted, height: 1.7)),
                  ]),
                ),
              ]),
            ),
        ]);
      }),
    );
  }
}

// ───────────────────────── Footer ─────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    Widget link(String t, [VoidCallback? onTap]) => TextButton(
          onPressed: onTap ?? () {},
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: Text(t),
        );
    return _Section(
      color: AppColors.ink,
      vertical: 40,
      child: Column(children: [
        const _Logo(light: true),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, children: [
          link('انضمام كمعلم'),
          link('تصفح المناهج', onBrowse),
          link('الدعم الفني عبر واتساب', () => _openWhatsapp('مرحباً، أحتاج إلى مساعدة')),
          link('الشروط والضمان'),
          link('سياسة الخصوصية'),
        ]),
        const SizedBox(height: 12),
        const Text('جميع الحقوق محفوظة لمنصة سياق التعليمية © ٢٠٢٥',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
      ]),
    );
  }
}
