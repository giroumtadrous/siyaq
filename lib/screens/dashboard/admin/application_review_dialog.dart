import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../../data/curriculum.dart';
import '../../../models/tutor_application.dart';
import '../../../models/user_model.dart';
import '../../../services/admin_service.dart';
import '../../../theme/app_theme.dart';

/// Shows everything a tutor submitted. For a pending application the admin can
/// approve it, or reject it with a reason the tutor will see.
/// Pops with the decision made, or null when closed without one.
class ApplicationReviewDialog extends StatefulWidget {
  const ApplicationReviewDialog({super.key, required this.tutor, required this.application});
  final AppUser tutor;
  final TutorApplication application;

  @override
  State<ApplicationReviewDialog> createState() => _ApplicationReviewDialogState();
}

class _ApplicationReviewDialogState extends State<ApplicationReviewDialog> {
  final _note = TextEditingController();
  bool _rejecting = false;
  bool _loading = false;
  String? _error;

  TutorApplication get _app => widget.application;
  bool get _pending => _app.status == ApplicationStatus.submitted;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide({required bool approve}) async {
    final note = _note.text.trim();
    if (!approve && (note.length < 3 || note.length > 500)) {
      setState(() => _error = 'اكتب سبب الرفض (3 أحرف على الأقل) ليعرف المعلم ما يعدّله.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context
          .read<AdminService>()
          .reviewApplication(widget.tutor.uid, approve: approve, note: note);
      if (mounted) Navigator.pop(context, approve ? ApplicationStatus.approved : ApplicationStatus.rejected);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذّر حفظ القرار. ربما تغيّر الطلب، أعد فتحه وحاول مرة أخرى.';
        });
      }
    }
  }

  Widget _field(String label, String value, {bool ltr = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final stageNames = [
      for (final s in stages)
        if (_app.stages.contains(s.id)) s.name,
    ];
    final tutorName = widget.tutor.name.isEmpty ? widget.tutor.email : widget.tutor.name;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('طلب $tutorName', style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'أُرسل في ${DateFormat('d MMMM y', 'ar').format(_app.submittedAt)}'
                '${_pending ? '' : ' • ${_app.status == ApplicationStatus.approved ? 'تم الاعتماد' : 'تم الرفض'}'}',
                style: const TextStyle(color: AppColors.muted)),
            const Divider(height: 24, color: AppColors.border),
            _field('البريد الإلكتروني', widget.tutor.email, ltr: true),
            _field('الهاتف', _app.phone, ltr: true),
            _field('المؤهل العلمي', _app.qualification),
            _field('سنوات الخبرة', '${_app.experienceYears}'),
            _field('المراحل', stageNames.join('، ')),
            _field('المواد', _app.subjects.join('، ')),
            _field('الأوقات المناسبة', _app.availability),
            _field('النبذة', _app.bio),
            if (_app.reviewNote != null) _field('سبب الرفض', _app.reviewNote!),
            if (_rejecting) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                autofocus: true,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'سبب الرفض (يراه المعلم)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => _rejecting
                  ? setState(() {
                      _rejecting = false;
                      _error = null;
                    })
                  : Navigator.pop(context),
          child: Text(_rejecting ? 'رجوع' : 'إغلاق'),
        ),
        if (_pending && !_rejecting) ...[
          TextButton(
            onPressed: _loading ? null : () => setState(() => _rejecting = true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('رفض'),
          ),
          FilledButton(
            onPressed: _loading ? null : () => _decide(approve: true),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('اعتماد المعلم'),
          ),
        ],
        if (_pending && _rejecting)
          FilledButton(
            onPressed: _loading ? null : () => _decide(approve: false),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            child: const Text('إرسال الرفض'),
          ),
      ],
    );
  }
}
