import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';

class SessionTakenException implements Exception {
  const SessionTakenException();
}

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

  /// Pending bookings no tutor has accepted yet, soonest first.
  Stream<List<TutoringSession>> unassignedSessions() {
    return _db
        .collection('sessions')
        .where('tutorId', isEqualTo: unassignedTutorId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => TutoringSession.fromMap(d.id, d.data()))
          .where((s) => s.status == SessionStatus.pending)
          .toList();
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return list;
    });
  }

  /// Claims an unassigned booking. A transaction guarantees two tutors can't
  /// both accept the same one.
  Future<void> acceptSession({
    required String sessionId,
    required String tutorId,
    String? googleMeetLink,
  }) async {
    final ref = _db.collection('sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists || snap.data()?['tutorId'] != unassignedTutorId) {
        throw const SessionTakenException();
      }
      tx.update(ref, {
        'tutorId': tutorId,
        'status': SessionStatus.confirmed.name,
        'googleMeetLink': googleMeetLink,
      });
    });
  }

  Future<void> updateSession(
    String sessionId, {
    SessionStatus? status,
    String? googleMeetLink,
  }) {
    return _db.collection('sessions').doc(sessionId).update({
      if (status != null) 'status': status.name,
      if (googleMeetLink != null) 'googleMeetLink': googleMeetLink,
    });
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
