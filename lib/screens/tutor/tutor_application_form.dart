import 'package:flutter/material.dart';

import '../../data/curriculum.dart';
import '../../models/tutor_application.dart';
import '../../theme/app_theme.dart';

/// Turns Arabic-Indic digits into ASCII so phone numbers and years validate
/// the same however the keyboard types them.
String normalizeDigits(String input) => input.splitMapJoin(
      RegExp('[٠-٩]'),
      onMatch: (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}',
      onNonMatch: (n) => n,
    );

final _phonePattern = RegExp(r'^\+?[0-9 ]{8,20}$');

/// The application form. Pre-fills from [initial] when a tutor resubmits after
/// a rejection.
class TutorApplicationForm extends StatefulWidget {
  const TutorApplicationForm({super.key, required this.onSubmit, this.initial});
  final TutorApplication? initial;
  final Future<void> Function(ApplicationDraft draft) onSubmit;

  @override
  State<TutorApplicationForm> createState() => _TutorApplicationFormState();
}

class _TutorApplicationFormState extends State<TutorApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _qualification = TextEditingController(text: widget.initial?.qualification);
  late final _years = TextEditingController(
      text: widget.initial == null ? '' : '${widget.initial!.experienceYears}');
  late final _bio = TextEditingController(text: widget.initial?.bio);
  late final _availability = TextEditingController(text: widget.initial?.availability);
  late final Set<String> _stages = {...?widget.initial?.stages};
  late final Set<String> _subjects = {...?widget.initial?.subjects};

  bool _showChipErrors = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_phone, _qualification, _years, _bio, _availability]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final fieldsOk = _formKey.currentState!.validate();
    setState(() => _showChipErrors = true);
    if (!fieldsOk || _stages.isEmpty || _subjects.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(ApplicationDraft(
        phone: normalizeDigits(_phone.text).trim(),
        qualification: _qualification.text.trim(),
        experienceYears: int.parse(normalizeDigits(_years.text).trim()),
        subjects: _subjects.toList(),
        stages: _stages.toList(),
        bio: _bio.text.trim(),
        availability: _availability.text.trim(),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر إرسال الطلب. تحقق من الاتصال ثم حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint, IconData? icon}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: AppColors.muted),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.indigo, 2),
      errorBorder: border(const Color(0xFFDC2626)),
      focusedErrorBorder: border(const Color(0xFFDC2626), 2),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Semantics(
          header: true,
          child: Text(text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      );

  Widget _chipError(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
      );

  Widget _chips<T>({
    required Iterable<T> options,
    required Set<String> selected,
    required String Function(T) id,
    required String Function(T) label,
  }) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          FilterChip(
            selected: selected.contains(id(o)),
            onSelected: (on) => setState(() {
              on ? selected.add(id(o)) : selected.remove(id(o));
            }),
            showCheckmark: false,
            label: Text(label(o)),
            labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected.contains(id(o)) ? Colors.white : AppColors.ink),
            selectedColor: AppColors.indigo,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('بياناتك'),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.next,
          decoration: _decoration('رقم الهاتف',
              hint: '+20 100 000 0000', icon: Icons.phone_outlined),
          validator: (v) => _phonePattern.hasMatch(normalizeDigits(v ?? '').trim())
              ? null
              : 'أدخل رقم هاتف صحيح (8 إلى 20 رقماً)',
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _qualification,
          textInputAction: TextInputAction.next,
          decoration: _decoration('المؤهل العلمي',
              hint: 'مثال: بكالوريوس تربية - جامعة القاهرة', icon: Icons.school_outlined),
          validator: (v) {
            final t = (v ?? '').trim();
            return t.length < 2 || t.length > 200 ? 'أدخل مؤهلك العلمي' : null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _years,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: _decoration('سنوات الخبرة في التدريس', icon: Icons.work_outline_rounded),
          validator: (v) {
            final n = int.tryParse(normalizeDigits(v ?? '').trim());
            return n == null || n < 0 || n > 50 ? 'أدخل رقماً بين 0 و 50' : null;
          },
        ),
        _heading('ما الذي تدرّسه؟'),
        const Text('المراحل',
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _chips<Stage>(
            options: stages,
            selected: _stages,
            id: (s) => s.id,
            label: (s) => s.name),
        if (_showChipErrors && _stages.isEmpty) _chipError('اختر مرحلة واحدة على الأقل'),
        const SizedBox(height: 18),
        const Text('المواد',
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _chips<Subject>(
            options: allSubjects(),
            selected: _subjects,
            id: (s) => s.name,
            label: (s) => s.name),
        if (_showChipErrors && _subjects.isEmpty) _chipError('اختر مادة واحدة على الأقل'),
        _heading('عنك'),
        TextFormField(
          controller: _bio,
          maxLines: 5,
          maxLength: 1000,
          decoration: _decoration('نبذة عن أسلوبك في التدريس').copyWith(alignLabelWithHint: true),
          validator: (v) => (v ?? '').trim().length < 20
              ? 'اكتب 20 حرفاً على الأقل عن خبرتك وأسلوبك'
              : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _availability,
          maxLength: 300,
          decoration: _decoration('الأوقات المناسبة لك',
              hint: 'مثال: مساءً بعد الخامسة، والجمعة طوال اليوم',
              icon: Icons.schedule_rounded),
          validator: (v) => (v ?? '').trim().isEmpty ? 'أخبرنا بالأوقات المناسبة لك' : null,
        ),
        const SizedBox(height: 8),
        if (_error != null) ...[
          Row(children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFB91C1C)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
          ]),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(widget.initial == null ? 'إرسال الطلب' : 'إعادة إرسال الطلب'),
        ),
      ]),
    );
  }
}
