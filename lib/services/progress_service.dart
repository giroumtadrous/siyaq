import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/progress_report.dart';

class ProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addReport({
    required String studentId,
    required String tutorId,
    required String subject,
    required double score,
    required String notes,
  }) {
    return _db.collection('progress_reports').add({
      'studentId': studentId,
      'tutorId': tutorId,
      'subject': subject,
      'score': score,
      'tutorNotes': notes,
      'date': DateTime.now().toIso8601String(),
    });
  }

  /// Newest first. Sorted client-side to avoid needing a composite index.
  Stream<List<ProgressReport>> reportsForStudent(String studentId) {
    return _db
        .collection('progress_reports')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ProgressReport.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
}
