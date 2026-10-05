import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';
import '../models/tutor_application.dart';
import '../models/user_model.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppUser>> allUsers() => _db.collection('users').snapshots().map(
      (s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());

  Stream<List<TutoringSession>> allSessions() => _db
      .collection('sessions')
      .snapshots()
      .map((s) => s.docs.map((d) => TutoringSession.fromMap(d.id, d.data())).toList());

  /// Every application, keyed by tutor uid.
  Stream<Map<String, TutorApplication>> allApplications() => _db
      .collection('tutor_applications')
      .snapshots()
      .map((s) => {
            for (final d in s.docs) d.id: TutorApplication.fromMap(d.id, d.data()),
          });

  /// Approves or rejects a submitted application. Approving also marks the
  /// tutor's profile approved, in one batch so the two can't drift apart.
  Future<void> reviewApplication(String tutorId,
      {required bool approve, String? note}) async {
    final batch = _db.batch();
    batch.update(_db.collection('tutor_applications').doc(tutorId), {
      'status': approve ? ApplicationStatus.approved.name : ApplicationStatus.rejected.name,
      if (!approve) 'reviewNote': note,
      'reviewedAt': DateTime.now().toIso8601String(),
    });
    if (approve) {
      batch.update(_db.collection('users').doc(tutorId), {'approved': true});
    }
    await batch.commit();
  }

  Future<void> setTutorApproved(String uid, bool approved) =>
      _db.collection('users').doc(uid).update({'approved': approved});

  /// Assigns a tutor to a booking and confirms it.
  Future<void> assignTutor(String sessionId, String tutorId) =>
      _db.collection('sessions').doc(sessionId).update({
        'tutorId': tutorId,
        'status': SessionStatus.confirmed.name,
      });
}
