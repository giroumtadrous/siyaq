import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../data/curriculum.dart';
import '../../models/session_model.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../theme/app_theme.dart';
import 'booking_pickers.dart';

/// Request a free trial class: pick a subject, a day and a start time. A tutor
/// accepts the request afterwards.
class TrialBookingScreen extends StatefulWidget {
  /// Book on behalf of this student (used by parents). Defaults to the
  /// signed-in user.
  final String? studentId;

  /// Shown when a parent books for a child.
  final String? studentName;

  const TrialBookingScreen({super.key, this.studentId, this.studentName});

  @override
  State<TrialBookingScreen> createState() => _TrialBookingScreenState();
}

class _TrialBookingScreenState extends State<TrialBookingScreen> {
  final DateTime _now = DateTime.now();
  late final List<DateTime> _days = bookableDays(_now);

  Subject? _subject;
  DateTime? _day;
  DateTime? _slot;
  bool _loading = false;
  bool _done = false;
  String? _error;

  List<DateTime> get _slots => _day == null ? const [] : availableSlots(_day!, _now);
  bool get _ready => _subject != null && _slot != null;

  String get _summary {
    if (!_ready) return 'اختر المادة واليوم والوقت.';
    final when = DateFormat('EEEE d MMMM • h:mm a', 'ar').format(_slot!);
    return '${_subject!.name} • $when';
  }

  Future<void> _submit() async {
    if (!_ready || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final studentId =
          widget.studentId ?? context.read<AuthService>().currentUser!.uid;
      await context.read<BookingService>().bookSession(
            studentId: studentId,
            tutorId: unassignedTutorId,
            subject: _subject!.name,
            scheduledAt: _slot!,
            isTrial: true,
          );
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر إرسال الحجز. تحقق من الاتصال ثم حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('حجز حصة تجريبية',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _done ? _Confirmation(summary: _summary) : _form(),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('الحصة الأولى مجانية وبدون أي التزام.',
                style: TextStyle(color: AppColors.muted, height: 1.6)),
            if (widget.studentName != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.indigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_rounded, size: 18, color: AppColors.indigo),
                    const SizedBox(width: 6),
                    Text('الحجز لـ ${widget.studentName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: AppColors.indigo)),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SectionTitle('المادة'),
            SubjectPicker(
                selected: _subject, onSelect: (s) => setState(() => _subject = s)),
            const SizedBox(height: 28),
            const SectionTitle('اليوم'),
            DayPicker(
              days: _days,
              selected: _day,
              now: _now,
              onSelect: (d) => setState(() {
                _day = d;
                if (_slot != null && !sameDay(_slot!, d)) _slot = null;
              }),
            ),
            const SizedBox(height: 28),
            const SectionTitle('الوقت'),
            if (_day == null)
              const Text('اختر اليوم أولاً لعرض الأوقات المتاحة.',
                  style: TextStyle(color: AppColors.muted))
            else
              TimePicker(
                slots: _slots,
                selected: _slot,
                onSelect: (s) => setState(() => _slot = s),
              ),
            const SizedBox(height: 20),
            const Text('هذا طلب موعد، وسيؤكده المعلم. ستجد حالته في لوحتك.',
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.6)),
          ]),
        ),
      ),
      _SummaryBar(
        summary: _summary,
        ready: _ready,
        loading: _loading,
        error: _error,
        onConfirm: _submit,
      ),
    ]);
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.summary,
    required this.ready,
    required this.loading,
    required this.error,
    required this.onConfirm,
  });
  final String summary;
  final bool ready, loading;
  final String? error;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (error != null) ...[
            Row(children: [
              const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(error!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
            ]),
            const SizedBox(height: 10),
          ],
          Semantics(
            liveRegion: true,
            child: Text(summary,
                style: TextStyle(
                    fontWeight: ready ? FontWeight.w800 : FontWeight.w500,
                    color: ready ? AppColors.ink : AppColors.muted)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: ready && !loading ? onConfirm : null,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('تأكيد الحجز'),
          ),
        ]),
      );
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.summary});
  final String summary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 44, color: Color(0xFF047857)),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            liveRegion: true,
            child: const Text('تم إرسال طلب الحجز',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          Text(summary,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
          const SizedBox(height: 8),
          const Text(
            'سيؤكد المعلم الموعد، وسيظهر رابط الحصة في لوحتك قبل البدء.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.7),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('العودة إلى لوحتي'),
          ),
        ]),
      );
}
