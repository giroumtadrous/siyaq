import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';
import '../models/tutor_profile.dart';

class TutorDirectoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Every listed (not suspended) tutor. The rules only allow this query with
  /// the `active` filter.
  Stream<List<TutorProfile>> activeTutors() => _db
      .collection('tutor_profiles')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => TutorProfile.fromMap(d.id, d.data())).toList());

  /// The student's ratings, keyed by session id.
  Stream<Map<String, int>> myRatings(String studentId) => _db
      .collection('reviews')
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((s) => {
            for (final d in s.docs) d.id: ((d.data()['rating'] ?? 0) as num).toInt(),
          });

  /// Rates a completed session 1–5. The review and the tutor's rating totals
  /// are written in one batch; the rules refuse either one alone.
  Future<void> rateSession(TutoringSession session, int rating) async {
    final profile = _db.collection('tutor_profiles').doc(session.tutorId);
    final listed = (await profile.get()).exists;
    final batch = _db.batch();
    batch.set(_db.collection('reviews').doc(session.id), {
      'studentId': session.studentId,
      'tutorId': session.tutorId,
      'rating': rating,
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (listed) {
      batch.update(profile, {
        'ratingSum': FieldValue.increment(rating),
        'ratingCount': FieldValue.increment(1),
        'lastReviewId': session.id,
      });
    }
    await batch.commit();
  }
}
