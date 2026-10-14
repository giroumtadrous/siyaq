import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';
import '../models/tutor_application.dart';
import '../models/tutor_profile.dart';
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

  /// Tutor uids in the directory, with whether each is currently shown.
  Stream<Map<String, bool>> directoryListings() =>
      _db.collection('tutor_profiles').snapshots().map((s) => {
            for (final d in s.docs) d.id: d.data()['active'] == true,
          });

  /// Approves or rejects a submitted application. Approving also marks the
  /// tutor's profile approved and lists them in the directory, in one batch
  /// so the three can't drift apart.
  Future<void> reviewApplication(AppUser tutor, TutorApplication application,
      {required bool approve, String? note}) async {
    final batch = _db.batch();
    batch.update(_db.collection('tutor_applications').doc(tutor.uid), {
      'status': approve ? ApplicationStatus.approved.name : ApplicationStatus.rejected.name,
      if (!approve) 'reviewNote': note,
      'reviewedAt': DateTime.now().toIso8601String(),
    });
    if (approve) {
      batch.update(_db.collection('users').doc(tutor.uid), {'approved': true});
      await _syncListing(batch, tutor, application, active: true);
    }
    await batch.commit();
  }

  /// Suspends or re-activates a tutor, hiding or showing them in the
  /// directory. [application] lists a re-activated tutor who isn't there yet.
  Future<void> setTutorApproved(AppUser tutor, bool approved,
      {TutorApplication? application}) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(tutor.uid), {'approved': approved});
    await _syncListing(batch, tutor, approved ? application : null, active: approved);
    await batch.commit();
  }

  /// Lists an approved tutor who isn't in the directory yet (approved before
  /// the directory existed).
  Future<void> addToDirectory(AppUser tutor, TutorApplication application) async {
    final batch = _db.batch();
    await _syncListing(batch, tutor, application, active: true);
    await batch.commit();
  }

  /// Shows or hides an existing listing, or creates one from [application].
  /// A new listing carries over the sessions the tutor already finished.
  Future<void> _syncListing(WriteBatch batch, AppUser tutor, TutorApplication? application,
      {required bool active}) async {
    final ref = _db.collection('tutor_profiles').doc(tutor.uid);
    if ((await ref.get()).exists) {
      batch.update(ref, {'active': active});
      return;
    }
    if (!active || application == null) return;
    final past = await _db.collection('sessions').where('tutorId', isEqualTo: tutor.uid).get();
    int count(SessionStatus s) => past.docs.where((d) => d.data()['status'] == s.name).length;
    batch.set(
        ref,
        TutorProfile.newListing(
          name: tutor.name,
          application: application,
          completedSessions: count(SessionStatus.completed),
          cancelledSessions: count(SessionStatus.cancelled),
        ));
  }

  /// Assigns a tutor to a booking and confirms it.
  Future<void> assignTutor(String sessionId, String tutorId) =>
      _db.collection('sessions').doc(sessionId).update({
        'tutorId': tutorId,
        'status': SessionStatus.confirmed.name,
      });
}
