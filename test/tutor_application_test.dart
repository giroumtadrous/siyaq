import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siyaq/data/curriculum.dart';
import 'package:siyaq/models/tutor_application.dart';
import 'package:siyaq/screens/tutor/tutor_application_form.dart';
import 'package:siyaq/screens/tutor/tutor_application_screen.dart';

Future<void> _pump(
  WidgetTester t,
  Future<void> Function(ApplicationDraft) onSubmit, {
  TutorApplication? initial,
  Size size = const Size(390, 1600),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    builder: (context, c) => Directionality(textDirection: TextDirection.rtl, child: c!),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TutorApplicationForm(onSubmit: onSubmit, initial: initial),
      ),
    ),
  ));
}

Future<void> _fill(WidgetTester t,
    {String phone = '+20 100 123 4567',
    String qualification = 'بكالوريوس تربية',
    String years = '5',
    String bio = 'معلم رياضيات بخبرة خمس سنوات في الشرح المبسط.',
    String availability = 'مساءً'}) async {
  final fields = find.byType(TextFormField);
  await t.enterText(fields.at(0), phone);
  await t.enterText(fields.at(1), qualification);
  await t.enterText(fields.at(2), years);
  await t.enterText(fields.at(3), bio);
  await t.enterText(fields.at(4), availability);
}

Future<void> _submit(WidgetTester t, [String label = 'إرسال الطلب']) async {
  final button = find.text(label);
  await t.ensureVisible(button);
  await t.tap(button);
  await t.pumpAndSettle();
}

final _initial = TutorApplication(
  tutorId: 't1',
  phone: '+20 100 123 4567',
  qualification: 'ماجستير مناهج',
  experienceYears: 8,
  subjects: const ['الرياضيات'],
  stages: const ['prep'],
  bio: 'نبذة طويلة بما يكفي لتجاوز الحد الأدنى للأحرف.',
  availability: 'مساءً',
  status: ApplicationStatus.rejected,
  submittedAt: DateTime(2030, 1, 1),
  reviewNote: 'يرجى توضيح المؤهل',
);

void main() {
  test('normalizeDigits converts Arabic-Indic digits and leaves the rest', () {
    expect(normalizeDigits('٠١٠٠ ١٢٣٤٥٦٧'), '0100 1234567');
    expect(normalizeDigits('+٢٠ 100'), '+20 100');
    expect(normalizeDigits('abc'), 'abc');
  });

  test('curriculum subjects and stage ids match what firestore.rules accepts', () {
    final rules = File('firestore.rules').readAsStringSync();
    for (final s in allSubjects()) {
      expect(rules, contains("'${s.name}'"),
          reason: 'subject "${s.name}" missing from firestore.rules');
    }
    for (final stage in stages) {
      expect(rules, contains("'${stage.id}'"), reason: 'stage ${stage.id} missing');
    }
  });

  group('TutorApplicationForm', () {
    testWidgets('shows what is missing and does not submit an empty form', (t) async {
      var submitted = false;
      await _pump(t, (_) async => submitted = true);
      await _submit(t);

      expect(submitted, isFalse);
      expect(find.text('أدخل رقم هاتف صحيح (8 إلى 20 رقماً)'), findsOneWidget);
      expect(find.text('أدخل مؤهلك العلمي'), findsOneWidget);
      expect(find.text('أدخل رقماً بين 0 و 50'), findsOneWidget);
      expect(find.text('اختر مرحلة واحدة على الأقل'), findsOneWidget);
      expect(find.text('اختر مادة واحدة على الأقل'), findsOneWidget);
    });

    testWidgets('needs a stage and a subject even when the text fields are valid', (t) async {
      var submitted = false;
      await _pump(t, (_) async => submitted = true);
      await _fill(t);
      await _submit(t);

      expect(submitted, isFalse);
      expect(find.text('اختر مرحلة واحدة على الأقل'), findsOneWidget);
    });

    testWidgets('submits normalized values', (t) async {
      ApplicationDraft? sent;
      await _pump(t, (d) async => sent = d);
      await _fill(t, phone: '٠١٠٠ ١٢٣ ٤٥٦٧', years: '٥');
      await t.ensureVisible(find.text('المرحلة الإعدادية'));
      await t.tap(find.text('المرحلة الإعدادية'));
      await t.ensureVisible(find.text('الرياضيات'));
      await t.tap(find.text('الرياضيات'));
      await t.pump();
      await _submit(t);

      expect(sent, isNotNull);
      expect(sent!.phone, '0100 123 4567');
      expect(sent!.experienceYears, 5);
      expect(sent!.stages, ['prep']);
      expect(sent!.subjects, ['الرياضيات']);
      final map = sent!.toSubmissionMap(DateTime(2030, 1, 1));
      expect(map['status'], 'submitted');
      expect(map.keys, isNot(contains('reviewNote')));
    });

    testWidgets('rejects out-of-range years and short bios', (t) async {
      var submitted = false;
      await _pump(t, (_) async => submitted = true);
      await _fill(t, years: '51', bio: 'قصير');
      await _submit(t);

      expect(submitted, isFalse);
      expect(find.text('أدخل رقماً بين 0 و 50'), findsOneWidget);
      expect(find.text('اكتب 20 حرفاً على الأقل عن خبرتك وأسلوبك'), findsOneWidget);
    });

    testWidgets('keeps the answers and shows an error when sending fails', (t) async {
      await _pump(t, (_) async => throw Exception('offline'), initial: _initial);
      await _submit(t, 'إعادة إرسال الطلب');

      expect(find.textContaining('تعذّر إرسال الطلب'), findsOneWidget);
      expect(find.text('ماجستير مناهج'), findsOneWidget, reason: 'answers are kept');
      // The button is usable again for a retry.
      final button = t.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('pre-fills from a rejected application and says "resubmit"', (t) async {
      await _pump(t, (_) async {}, initial: _initial);
      expect(find.text('ماجستير مناهج'), findsOneWidget);
      expect(find.text('إعادة إرسال الطلب'), findsOneWidget);
      expect(find.text('إرسال الطلب'), findsNothing);
    });

    testWidgets('lays out without overflow at phone and desktop widths', (t) async {
      for (final size in const [Size(320, 1600), Size(1440, 1600)]) {
        await _pump(t, (_) async {}, size: size);
        expect(t.takeException(), isNull, reason: '${size.width}px');
      }
    });
  });

  group('ApplicationTracker', () {
    Future<void> pumpTracker(WidgetTester t, int step) => t.pumpWidget(MaterialApp(
          builder: (context, c) => Directionality(textDirection: TextDirection.rtl, child: c!),
          home: Scaffold(body: ApplicationTracker(step: step)),
        ));

    testWidgets('names the current step for screen readers', (t) async {
      final handle = t.ensureSemantics();
      await pumpTracker(t, 1);
      expect(find.bySemanticsLabel('الخطوة 2 من 3: المراجعة'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('marks finished steps with a check', (t) async {
      await pumpTracker(t, 2);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });
  });
}
