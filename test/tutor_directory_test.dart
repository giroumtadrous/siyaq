import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:siyaq/data/curriculum.dart';
import 'package:siyaq/models/session_model.dart';
import 'package:siyaq/models/tutor_application.dart';
import 'package:siyaq/models/tutor_profile.dart';
import 'package:siyaq/screens/dashboard/student/next_class_card.dart' show arabicNumber;
import 'package:siyaq/screens/dashboard/student/student_sections.dart';
import 'package:siyaq/screens/directory/tutor_directory_screen.dart';
import 'package:siyaq/services/tutor_ranking.dart';

const _math = 'الرياضيات';
const _english = 'اللغة الإنجليزية';
const _quran = 'القرآن الكريم';

TutorProfile _tutor(
  String name, {
  List<int> ratings = const [],
  int completed = 0,
  int cancelled = 0,
  int years = 3,
  List<String> subjects = const [_math],
  List<String> stages = const ['primary', 'prep', 'secondary'],
  bool active = true,
}) =>
    TutorProfile(
      tutorId: name,
      name: name,
      subjects: subjects,
      stages: stages,
      qualification: 'بكالوريوس',
      experienceYears: years,
      bio: 'نبذة',
      active: active,
      ratingSum: ratings.fold(0, (a, b) => a + b),
      ratingCount: ratings.length,
      completedSessions: completed,
      cancelledSessions: cancelled,
    );

List<String> _names(Iterable<TutorProfile> ts) => [for (final t in ts) t.name];

Stage _stage(String id) => stages.firstWhere((s) => s.id == id);

Future<void> _pump(WidgetTester t, Widget child, {Size size = const Size(390, 800)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    builder: (context, c) => Directionality(textDirection: TextDirection.rtl, child: c!),
    home: child,
  ));
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('rankTutors', () {
    test('many good ratings beat a single perfect one', () {
      final ranked = rankTutors([
        _tutor('one-review', ratings: [5], completed: 1),
        _tutor('proven', ratings: List.filled(40, 5)..[0] = 4, completed: 40),
      ]);
      expect(_names(ranked), ['proven', 'one-review']);
    });

    test('ratings outweigh volume', () {
      final ranked = rankTutors([
        _tutor('busy-but-weak', ratings: List.filled(30, 3), completed: 100),
        _tutor('excellent', ratings: List.filled(30, 5), completed: 30),
      ]);
      expect(_names(ranked), ['excellent', 'busy-but-weak']);
    });

    test('a brand-new tutor ranks between strong and poorly rated tutors', () {
      final ranked = rankTutors([
        _tutor('poor', ratings: List.filled(20, 2), completed: 20),
        _tutor('new'),
        _tutor('strong', ratings: List.filled(20, 5), completed: 20),
      ]);
      expect(_names(ranked), ['strong', 'new', 'poor']);
    });

    test('cancelling sessions costs rank when everything else is equal', () {
      final ranked = rankTutors([
        _tutor('cancels', ratings: [5, 5, 5], completed: 10, cancelled: 8),
        _tutor('reliable', ratings: [5, 5, 5], completed: 10),
      ]);
      expect(_names(ranked), ['reliable', 'cancels']);
    });

    test('more teaching experience breaks a near tie', () {
      final ranked = rankTutors([_tutor('junior', years: 1), _tutor('senior', years: 12)]);
      expect(_names(ranked), ['senior', 'junior']);
    });

    test('identical tutors are ordered by name so the list never jumps', () {
      expect(_names(rankTutors([_tutor('b'), _tutor('a'), _tutor('c')])), ['a', 'b', 'c']);
    });

    test('scores stay within 0–1 at the extremes', () {
      for (final t in [
        _tutor('floor', ratings: List.filled(500, 1), cancelled: 500, years: 0),
        _tutor('ceiling', ratings: List.filled(500, 5), completed: 5000, years: 50),
      ]) {
        expect(TutorRanking.score(t), inInclusiveRange(0, 1));
      }
    });
  });

  group('groupTutors', () {
    final tutors = [
      _tutor('math-all', ratings: [5, 5]),
      _tutor('math-secondary', stages: ['secondary']),
      _tutor('english-primary', subjects: [_english], stages: ['primary']),
      _tutor('quran-prep', subjects: [_quran], stages: ['prep']),
      _tutor('suspended', active: false),
    ];

    test('groups one ranked list per subject of the stage', () {
      final groups = groupTutors(tutors, stage: _stage('secondary'));
      expect([for (final g in groups) g.$1.name], [_math]);
      expect(_names(groups.single.$2), ['math-all', 'math-secondary']);
    });

    test('a grade narrows to the subjects taught in that year', () {
      final primary = _stage('primary');
      // English isn't taught in the first primary year.
      final first = groupTutors(tutors, stage: primary, grade: primary.grades[0]);
      expect([for (final g in first) g.$1.name], [_math]);
      final second = groupTutors(tutors, stage: primary, grade: primary.grades[1]);
      expect([for (final g in second) g.$1.name], [_math, _english]);
    });

    test('a subject filter and a name search narrow further', () {
      final prep = _stage('prep');
      final quran = subjectsFor(prep).firstWhere((s) => s.name == _quran);
      expect(_names(groupTutors(tutors, stage: prep, subject: quran).single.$2), ['quran-prep']);
      expect(groupTutors(tutors, stage: prep, query: 'MATH').single.$2.length, 1);
      expect(groupTutors(tutors, stage: prep, query: 'nobody'), isEmpty);
    });

    test('suspended tutors never appear', () {
      final all = groupTutors(tutors, stage: _stage('prep'));
      expect(all.expand((g) => g.$2).map((t) => t.name), isNot(contains('suspended')));
    });
  });

  test('a new listing copies the application and starts with no ratings', () {
    final app = TutorApplication(
      tutorId: 't1',
      phone: '0100',
      qualification: 'ليسانس آداب',
      experienceYears: 4,
      subjects: const [_math],
      stages: const ['prep'],
      bio: 'نبذة طويلة بما يكفي',
      availability: 'مساءً',
      status: ApplicationStatus.approved,
      submittedAt: DateTime(2030),
    );
    final map = TutorProfile.newListing(name: 'منى', application: app, completedSessions: 3);
    final back = TutorProfile.fromMap('t1', map);
    expect(back.subjects, app.subjects);
    expect(back.experienceYears, 4);
    expect(back.completedSessions, 3);
    expect(back.averageRating, isNull);
    expect(back.active, isTrue);
    expect(map['lastSessionId'], '');
    expect(map['lastReviewId'], '');
  });

  group('TutorDirectoryScreen', () {
    Widget screen(List<TutorProfile> tutors) =>
        TutorDirectoryScreen(tutors: Stream.value(tutors));

    testWidgets('shows ranked tutors for the chosen stage and subject', (t) async {
      await _pump(
          t,
          screen([
            _tutor('منى', ratings: [5, 5, 5, 5], completed: 12),
            _tutor('أحمد', ratings: [3]),
            _tutor('سارة', subjects: [_english], stages: ['secondary']),
          ]));
      await t.pump();
      expect(find.text('منى'), findsOneWidget);
      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('سارة'), findsNothing); // secondary only
      expect(t.getTopLeft(find.text('منى')).dy, lessThan(t.getTopLeft(find.text('أحمد')).dy));
      expect(find.bySemanticsLabel(RegExp('المرتبة ${arabicNumber(1)}\\b')), findsOneWidget);

      await t.tap(find.text('المرحلة الثانوية'));
      await t.pump();
      expect(find.text('سارة'), findsOneWidget);
    });

    testWidgets('explains an empty result', (t) async {
      await _pump(t, screen(const []));
      await t.pump();
      expect(find.textContaining('لا يوجد معلمون متاحون'), findsOneWidget);
    });

    testWidgets('opens the details of a tutor', (t) async {
      await _pump(t, screen([_tutor('منى', ratings: [4, 5], completed: 9, cancelled: 1)]));
      await t.pump();
      await t.ensureVisible(find.text('منى'));
      await t.tap(find.text('منى'));
      await t.pumpAndSettle();
      expect(find.text('حصة مكتملة'), findsOneWidget);
      expect(find.text('${arabicNumber(90)}٪'), findsOneWidget); // reliability
    });

    testWidgets('shows an error instead of spinning forever', (t) async {
      await _pump(t, TutorDirectoryScreen(tutors: Stream.error(StateError('denied'))));
      await t.pump();
      expect(find.textContaining('تعذّر تحميل المعلمين'), findsOneWidget);
    });

    for (final size in const [Size(320, 640), Size(768, 1024), Size(1440, 900)]) {
      testWidgets('renders without overflow at ${size.width.toInt()}px', (t) async {
        await _pump(
            t,
            screen([
              for (var i = 0; i < 6; i++)
                _tutor('معلم رقم $i باسم طويل جداً لاختبار القص',
                    ratings: List.filled(i * 3, 4), completed: i * 7, subjects: [_math, _quran]),
            ]),
            size: size);
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  });

  group('rating a session', () {
    final now = DateTime(2030, 1, 10, 12);
    TutoringSession done(String id, {String tutorId = 'tutor1'}) => TutoringSession(
          id: id,
          studentId: 'me',
          tutorId: tutorId,
          subject: _math,
          scheduledAt: now.subtract(const Duration(days: 1)),
          isTrial: false,
          status: SessionStatus.completed,
        );

    testWidgets('offers rating only for unrated sessions with a tutor', (t) async {
      final rated = <String>[];
      await _pump(
          t,
          Scaffold(
            body: SingleChildScrollView(
              child: ScheduleSection(
                upcoming: const [],
                past: [done('a'), done('b'), done('c', tutorId: unassignedTutorId)],
                showUpcoming: false,
                onTab: (_) {},
                onBook: () {},
                now: now,
                ratings: const {'b': 4},
                onRate: (s) => rated.add(s.id),
              ),
            ),
          ));
      expect(find.text('قيّم الحصة'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('قيّمتها ${arabicNumber(4)} من ٥')), findsOneWidget);
      await t.tap(find.text('قيّم الحصة'));
      expect(rated, ['a']);
    });
  });

  testWidgets('dashboard panel shows the top three and opens the directory', (t) async {
    var browsed = false;
    await _pump(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: TopTutorsSection(
              tutors: [
                for (var i = 0; i < 5; i++) _tutor('t$i', ratings: List.filled(i + 1, 5)),
              ],
              onBrowse: () => browsed = true,
            ),
          ),
        ));
    expect(find.text('t4'), findsOneWidget);
    expect(find.text('t2'), findsOneWidget);
    expect(find.text('t1'), findsNothing);
    await t.tap(find.text('ابحث عن معلم حسب الصف والمادة'));
    expect(browsed, isTrue);
  });
}
