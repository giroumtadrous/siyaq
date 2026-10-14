import 'package:flutter/material.dart';

import '../../data/curriculum.dart';
import '../../models/tutor_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_widgets.dart';
import '../dashboard/student/next_class_card.dart' show arabicNumber;

String _rating(double v) => arabicNumber(double.parse(v.toStringAsFixed(1)));

String stageName(String id) =>
    stages.where((s) => s.id == id).map((s) => s.name).firstOrNull ?? id;

/// Five stars, filled to the nearest half.
class RatingStars extends StatelessWidget {
  const RatingStars(this.value, {super.key, this.size = 16});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final halves = (value * 2).round();
    return ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            halves >= i * 2
                ? Icons.star_rounded
                : halves == i * 2 - 1
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: AppColors.amber,
          ),
      ]),
    );
  }
}

/// "★★★★☆ ٤٫٥ (١٢ تقييم)", or a "new" badge before the first rating.
class RatingSummary extends StatelessWidget {
  const RatingSummary(this.tutor, {super.key});
  final TutorProfile tutor;

  @override
  Widget build(BuildContext context) {
    final avg = tutor.averageRating;
    if (avg == null) return const DashBadge('معلم جديد', AppColors.violet);
    final label = '${_rating(avg)} من ٥، ${arabicNumber(tutor.ratingCount)} تقييم';
    return Semantics(
      label: 'التقييم $label',
      excludeSemantics: true,
      child: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        RatingStars(avg),
        Text(_rating(avg), style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('(${arabicNumber(tutor.ratingCount)})',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }
}

/// One ranked row in the directory. [rank] is 1-based.
class TutorCard extends StatelessWidget {
  const TutorCard({super.key, required this.tutor, required this.rank, this.onTap});
  final TutorProfile tutor;
  final int rank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final top = rank <= 3;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Semantics(
                label: 'المرتبة ${arabicNumber(rank)}',
                excludeSemantics: true,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: top ? AppColors.amber.withValues(alpha: 0.18) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(arabicNumber(rank),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: top ? readableOn(AppColors.amber) : AppColors.muted)),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: AppColors.indigo.withValues(alpha: 0.12),
                child: Text(tutor.name.isEmpty ? '؟' : tutor.name.characters.first,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.indigo)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tutor.name.isEmpty ? 'معلم' : tutor.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  RatingSummary(tutor),
                  const SizedBox(height: 4),
                  Text(
                    '${arabicNumber(tutor.completedSessions)} حصة مكتملة • '
                    'خبرة ${arabicNumber(tutor.experienceYears)} سنوات',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ]),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bio, qualification and the numbers behind the tutor's rank.
Future<void> showTutorDetails(BuildContext context, TutorProfile tutor) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _TutorDetails(tutor: tutor),
    );

class _TutorDetails extends StatelessWidget {
  const _TutorDetails({required this.tutor});
  final TutorProfile tutor;

  @override
  Widget build(BuildContext context) {
    final finished = tutor.completedSessions + tutor.cancelledSessions;
    final avg = tutor.averageRating;

    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tutor.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tutor.qualification, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          Row(children: [
            stat(avg == null ? '—' : _rating(avg),
                avg == null ? 'لا تقييمات بعد' : '${arabicNumber(tutor.ratingCount)} تقييم'),
            stat(arabicNumber(tutor.completedSessions), 'حصة مكتملة'),
            stat(
                finished == 0
                    ? '—'
                    : '${arabicNumber((100 * tutor.completedSessions / finished).round())}٪',
                'التزام بالحصص'),
            stat(arabicNumber(tutor.experienceYears), 'سنوات خبرة'),
          ]),
          const Divider(height: 32, color: AppColors.border),
          Text(tutor.bio, style: const TextStyle(height: 1.7)),
          const SizedBox(height: 18),
          const Text('المواد', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in tutor.subjects) DashBadge(s, AppColors.indigo),
          ]),
          const SizedBox(height: 14),
          const Text('المراحل', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in tutor.stages) DashBadge(stageName(s), AppColors.violet),
          ]),
        ]),
      ),
    );
  }
}

/// Asks for a 1–5 rating. Returns null if dismissed.
class RateSessionDialog extends StatefulWidget {
  const RateSessionDialog({super.key, required this.subject});
  final String subject;

  @override
  State<RateSessionDialog> createState() => _RateSessionDialogState();
}

class _RateSessionDialogState extends State<RateSessionDialog> {
  int _rating = 0;

  static const _labels = ['ضعيفة', 'مقبولة', 'جيدة', 'جيدة جداً', 'ممتازة'];

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('قيّم الحصة', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.subject.isEmpty ? 'كيف كانت الحصة؟' : 'كيف كانت حصة ${widget.subject}؟',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '${arabicNumber(i)} من ٥ — ${_labels[i - 1]}',
                isSelected: _rating >= i,
                onPressed: () => setState(() => _rating = i),
                icon: Icon(
                  _rating >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 34,
                  color: AppColors.amber,
                ),
              ),
          ]),
          SizedBox(
            height: 22,
            child: Text(_rating == 0 ? '' : _labels[_rating - 1],
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          const Text('لا يمكن تعديل التقييم بعد إرساله.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لاحقاً')),
          FilledButton(
            onPressed: _rating == 0 ? null : () => Navigator.pop(context, _rating),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            child: const Text('إرسال'),
          ),
        ],
      );
}
