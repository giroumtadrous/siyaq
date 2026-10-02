import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';

class BookingService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Books a session. `googleMeetLink` is entered manually by the tutor for
  /// now (simple flow) — swap in the Calendar API call later if you want the
  /// automated flow instead.
  Future<void> bookSession({
    required String studentId,
    required String tutorId,
    required String subject,
    required DateTime scheduledAt,
    required bool isTrial,
    String? googleMeetLink,
  }) async {
    final session = TutoringSession(
      id: '',
      studentId: studentId,
      tutorId: tutorId,
      subject: subject,
      scheduledAt: scheduledAt,
      isTrial: isTrial,
      status: SessionStatus.pending,
      googleMeetLink: googleMeetLink,
    );
    await _db.collection('sessions').add(session.toMap());
    notifyListeners();
  }

  Stream<List<TutoringSession>> sessionsForUser(String uid, {bool asTutor = false}) {
    final field = asTutor ? 'tutorId' : 'studentId';
    return _db
        .collection('sessions')
        .where(field, isEqualTo: uid)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TutoringSession.fromMap(d.id, d.data()))
            .toList());
  }
}
