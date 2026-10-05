import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tutor_application.dart';

class TutorApplicationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('tutor_applications').doc(uid);

  /// The tutor's own application, or null before they have submitted one.
  Stream<TutorApplication?> watch(String uid) => _doc(uid).snapshots().map(
      (d) => d.exists ? TutorApplication.fromMap(d.id, d.data()!) : null);

  /// Submits a first application, or resubmits after a rejection. The whole
  /// document is replaced, which also clears the previous review fields.
  Future<void> submit(String uid, ApplicationDraft draft) =>
      _doc(uid).set(draft.toSubmissionMap(DateTime.now()));
}
