/// A tutor's progress note for a student, stored in `progress_reports`.
class ProgressReport {
  final String id;
  final String studentId;
  final String subject;

  /// 0–100.
  final double score;
  final String notes;
  final DateTime date;

  ProgressReport({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.score,
    required this.notes,
    required this.date,
  });

  factory ProgressReport.fromMap(String id, Map<String, dynamic> map) {
    return ProgressReport(
      id: id,
      studentId: map['studentId'] ?? '',
      subject: map['subject'] ?? '',
      score: ((map['score'] ?? 0) as num).toDouble().clamp(0, 100).toDouble(),
      notes: map['tutorNotes'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    );
  }
}
