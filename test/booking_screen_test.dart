import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:siyaq/screens/booking/booking_pickers.dart';
import 'package:siyaq/screens/booking/trial_booking_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('availableSlots', () {
    test('offers 9:00–21:00 hourly on a future day', () {
      final now = DateTime(2030, 1, 10, 12);
      final slots = availableSlots(DateTime(2030, 1, 11), now);
      expect(slots.first, DateTime(2030, 1, 11, 9));
      expect(slots.last, DateTime(2030, 1, 11, 21));
      expect(slots.length, 13);
    });

    test('hides times earlier than the 2-hour lead time today', () {
      final now = DateTime(2030, 1, 10, 12, 30);
      final slots = availableSlots(DateTime(2030, 1, 10), now);
      // 14:30 is the earliest; the first whole hour after it is 15:00.
      expect(slots.first, DateTime(2030, 1, 10, 15));
      expect(slots.every((s) => s.isAfter(now.add(bookingLeadTime))), isTrue);
    });

    test('is empty late in the evening', () {
      final now = DateTime(2030, 1, 10, 20);
      expect(availableSlots(DateTime(2030, 1, 10), now), isEmpty);
    });
  });

  group('bookableDays', () {
    test('starts today when slots remain', () {
      final now = DateTime(2030, 1, 10, 9);
      final days = bookableDays(now);
      expect(days.first, DateTime(2030, 1, 10));
      expect(days.length, bookingHorizonDays + 1);
    });

    test('skips today once no slots are left', () {
      final now = DateTime(2030, 1, 10, 21, 30);
      final days = bookableDays(now);
      expect(days.first, DateTime(2030, 1, 11));
      expect(days.length, bookingHorizonDays);
    });
  });

  test('bookableSubjects has no duplicates', () {
    final names = bookableSubjects().map((s) => s.name).toList();
    expect(names.toSet().length, names.length);
    expect(names, contains('الرياضيات'));
  });

  group('TrialBookingScreen', () {
    Future<void> pump(WidgetTester t, {String? studentName, Size size = const Size(390, 844)}) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        builder: (context, c) => Directionality(textDirection: TextDirection.rtl, child: c!),
        home: TrialBookingScreen(studentName: studentName),
      ));
    }

    FilledButton confirm(WidgetTester t) =>
        t.widget<FilledButton>(find.widgetWithText(FilledButton, 'تأكيد الحجز'));

    testWidgets('confirm unlocks only with subject, day and time; changing day clears the time',
        (t) async {
      await pump(t);
      final days = bookableDays(DateTime.now());
      final subjects = bookableSubjects().length;
      String dayNumber(int i) => DateFormat('d', 'ar').format(days[i]);

      expect(confirm(t).onPressed, isNull);
      expect(find.text('اختر المادة واليوم والوقت.'), findsOneWidget);

      await t.tap(find.text('الرياضيات'));
      await t.pump();
      expect(confirm(t).onPressed, isNull, reason: 'subject alone is not enough');

      await t.ensureVisible(find.text(dayNumber(1)));
      await t.tap(find.text(dayNumber(1)));
      await t.pump();
      expect(confirm(t).onPressed, isNull, reason: 'no time chosen yet');

      final firstSlot = find.byType(ChoiceChip).at(subjects);
      await t.ensureVisible(firstSlot);
      await t.tap(firstSlot);
      await t.pump();
      expect(confirm(t).onPressed, isNotNull);
      expect(find.textContaining('الرياضيات •'), findsOneWidget);

      await t.ensureVisible(find.text(dayNumber(2)));
      await t.tap(find.text(dayNumber(2)));
      await t.pump();
      expect(confirm(t).onPressed, isNull, reason: 'time belonged to the previous day');
    });

    testWidgets('shows a prompt instead of times before a day is picked', (t) async {
      await pump(t);
      expect(find.text('اختر اليوم أولاً لعرض الأوقات المتاحة.'), findsOneWidget);
    });

    testWidgets('names the child when a parent books for one', (t) async {
      await pump(t, studentName: 'سارة');
      expect(find.text('الحجز لـ سارة'), findsOneWidget);
    });

    testWidgets('lays out without overflow on phone and desktop', (t) async {
      for (final size in const [Size(320, 640), Size(1440, 900)]) {
        await pump(t, size: size);
        expect(t.takeException(), isNull, reason: '${size.width}px');
      }
    });
  });
}
