import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:siyaq/models/progress_report.dart';
import 'package:siyaq/models/session_model.dart';
import 'package:siyaq/screens/dashboard/student/next_class_card.dart';
import 'package:siyaq/screens/dashboard/student/student_sections.dart';

final _now = DateTime(2030, 1, 10, 12, 0);

TutoringSession _session({
  required Duration startsIn,
  SessionStatus status = SessionStatus.confirmed,
  String tutorId = 'tutor1',
  String? link = 'https://meet.google.com/abc-defg-hij',
  bool trial = false,
  String subject = 'الرياضيات',
}) =>
    TutoringSession(
      id: 's${startsIn.inMinutes}',
      studentId: 'me',
      tutorId: tutorId,
      subject: subject,
      scheduledAt: _now.add(startsIn),
      isTrial: trial,
      status: status,
      googleMeetLink: link,
    );

Future<void> _pump(WidgetTester t, Widget child, {Size size = const Size(390, 800)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    builder: (context, c) => Directionality(textDirection: TextDirection.rtl, child: c!),
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
  ));
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('NextClassCard', () {
    testWidgets('unlocks Join inside the 15-minute window', (t) async {
      await _pump(t, NextClassCard(session: _session(startsIn: const Duration(minutes: 10)), now: _now));
      expect(find.text('انضم إلى الحصة'), findsOneWidget);
      expect(find.textContaining('تبدأ بعد'), findsOneWidget);
    });

    testWidgets('keeps Join locked when the class is hours away', (t) async {
      await _pump(t, NextClassCard(session: _session(startsIn: const Duration(hours: 3)), now: _now));
      expect(find.text('انضم إلى الحصة'), findsNothing);
      expect(find.textContaining('يفتح الانضمام قبل الموعد'), findsOneWidget);
    });

    testWidgets('explains when the tutor has not added a link', (t) async {
      await _pump(t, NextClassCard(session: _session(startsIn: const Duration(minutes: 5), link: null), now: _now));
      expect(find.text('انضم إلى الحصة'), findsNothing);
      expect(find.textContaining('سيضيف المعلم رابط الحصة'), findsOneWidget);
    });

    testWidgets('shows an unassigned booking as waiting for a tutor', (t) async {
      await _pump(
          t,
          NextClassCard(
              session: _session(
                  startsIn: const Duration(days: 2),
                  status: SessionStatus.pending,
                  tutorId: unassignedTutorId,
                  link: null,
                  trial: true),
              now: _now));
      expect(find.text('بانتظار تعيين معلم'), findsOneWidget);
      expect(find.textContaining('حصة تجريبية'), findsOneWidget);
      expect(find.text('انضم إلى الحصة'), findsNothing);
    });

    testWidgets('marks a started confirmed class as live', (t) async {
      await _pump(t, NextClassCard(session: _session(startsIn: const Duration(minutes: -20)), now: _now));
      expect(find.text('جارية الآن'), findsOneWidget);
      expect(find.text('انضم إلى الحصة'), findsOneWidget);
    });
  });

  group('ScheduleSection', () {
    ScheduleSection build(List<TutoringSession> up, List<TutoringSession> past,
            {bool showUpcoming = true}) =>
        ScheduleSection(
          upcoming: up,
          past: past,
          showUpcoming: showUpcoming,
          onTab: (_) {},
          onBook: () {},
          now: _now,
        );

    testWidgets('groups by day with today / tomorrow headings', (t) async {
      await _pump(
          t,
          build([
            _session(startsIn: const Duration(hours: 2)),
            _session(startsIn: const Duration(hours: 4), subject: 'العربية'),
            _session(startsIn: const Duration(hours: 26), subject: 'القرآن الكريم'),
          ], []));
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('غداً'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('empty upcoming list invites the student to book', (t) async {
      await _pump(t, build([], []));
      expect(find.text('لا توجد حصص قادمة'), findsOneWidget);
      expect(find.text('احجز حصة تجريبية مجانية'), findsOneWidget);
    });

    testWidgets('past tab shows completed and cancelled with text labels', (t) async {
      await _pump(
          t,
          build([], [
            _session(startsIn: const Duration(days: -1), status: SessionStatus.completed),
            _session(startsIn: const Duration(days: -2), status: SessionStatus.cancelled),
          ], showUpcoming: false));
      expect(find.text('مكتملة'), findsOneWidget);
      expect(find.text('ملغاة'), findsOneWidget);
    });
  });

  group('ProgressSection', () {
    ProgressReport r(String subject, double score, int daysAgo, [String notes = '']) =>
        ProgressReport(
            id: '$subject$daysAgo',
            studentId: 'me',
            subject: subject,
            score: score,
            notes: notes,
            date: _now.subtract(Duration(days: daysAgo)));

    testWidgets('shows the latest score per subject and the newest note', (t) async {
      await _pump(
          t,
          ProgressSection(completed: 7, reports: [
            r('الرياضيات', 90, 1, 'أداء ممتاز'),
            r('الرياضيات', 60, 10, 'ملاحظة قديمة'),
            r('العربية', 40, 3),
          ]));
      expect(find.text('الرياضيات'), findsOneWidget); // not duplicated
      expect(find.text('أداء ممتاز'), findsOneWidget);
      expect(find.text('ملاحظة قديمة'), findsNothing);
    });

    testWidgets('empty state tells the student what to expect', (t) async {
      await _pump(t, const ProgressSection(completed: 0, reports: []));
      expect(find.textContaining('ستظهر نتائجك هنا'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final size in const [Size(320, 640), Size(768, 1024), Size(1440, 900)]) {
      testWidgets('renders without overflow at ${size.width.toInt()}px', (t) async {
        await _pump(
            t,
            Column(children: [
              NextClassCard(session: _session(startsIn: const Duration(minutes: 5), trial: true), now: _now),
              const SizedBox(height: 16),
              ScheduleSection(
                upcoming: [
                  _session(startsIn: const Duration(hours: 1), subject: 'اللغة الإنجليزية — مراجعة القواعد والمفردات'),
                  _session(startsIn: const Duration(hours: 30)),
                ],
                past: const [],
                showUpcoming: true,
                onTab: (_) {},
                onBook: () {},
                now: _now,
              ),
              const SizedBox(height: 16),
              const LinkCodeSection(code: 'AbCdEfGhIjKlMnOpQrStUvWxYz12'),
            ]),
            size: size);
        expect(t.takeException(), isNull);
      });
    }
  });
}
