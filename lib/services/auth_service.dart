import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class ChildLinkException implements Exception {
  const ChildLinkException(this.message);
  final String message;
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppUser? _currentUser;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  bool get isLoggedIn => _currentUser != null;
  UserRole get userRole => _currentUser?.role ?? UserRole.student;
  AppUser? get currentUser => _currentUser;

  void _onAuthChanged(User? firebaseUser) {
    _profileSub?.cancel();
    _profileSub = null;
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }
    // Live profile: role, approval and linked children update without a re-login.
    _profileSub = _db
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((doc) {
      // During sign-up the profile doesn't exist yet; signUp() sets it.
      if (!doc.exists) return;
      _currentUser = AppUser.fromMap(firebaseUser.uid, doc.data() ?? {});
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final user = AppUser(
      uid: uid,
      name: name,
      email: email.trim().toLowerCase(),
      role: role,
      approved: role != UserRole.tutor,
    );
    await _db.collection('users').doc(uid).set(user.toMap());
    // The auth listener may have read the profile before it existed (role
    // would default to student), so set the real profile explicitly.
    _currentUser = user;
    notifyListeners();
  }

  /// Live profiles of the given student uids (Firestore `whereIn` allows 30).
  Stream<List<AppUser>> childrenStream(List<String> ids) => usersStream(ids);

  /// Live profiles for any set of uids (up to 30 distinct). Reads each
  /// profile as its own document so Firestore rules can authorize them one by
  /// one; a single `whereIn` query can't be checked against per-document rules.
  Stream<List<AppUser>> usersStream(Iterable<String> ids) {
    final unique = ids.toSet().take(30).toList();
    if (unique.isEmpty) return Stream.value(const []);

    final latest = <String, AppUser?>{};
    final subs = <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
    late final StreamController<List<AppUser>> controller;

    void emit() {
      if (latest.length < unique.length) return; // wait for every first value
      controller.add([
        for (final id in unique)
          if (latest[id] != null) latest[id]!,
      ]);
    }

    controller = StreamController<List<AppUser>>.broadcast(
      onListen: () {
        for (final id in unique) {
          subs.add(_db.collection('users').doc(id).snapshots().listen(
            (doc) {
              latest[id] = doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null;
              emit();
            },
            onError: controller.addError,
          ));
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        subs.clear();
      },
    );
    return controller.stream;
  }

  /// Links a student to the signed-in parent using the student's link code
  /// (their uid, shown on the student dashboard). Knowing the code is what
  /// authorizes reading that student's profile.
  Future<void> linkChildByCode(String code) async {
    final me = _currentUser;
    if (me == null || me.role != UserRole.parent) {
      throw const ChildLinkException('هذه الميزة متاحة لأولياء الأمور فقط');
    }
    const invalid = ChildLinkException('رمز الربط غير صحيح. اطلبه من ابنك من لوحة الطالب.');
    final id = code.trim();
    if (id.isEmpty || id.contains('/') || id == me.uid) throw invalid;

    try {
      // A missing doc and a non-student doc are both denied by the rules, so
      // this can't be used to probe which uids exist.
      final doc = await _db.collection('users').doc(id).get();
      if (!doc.exists || doc.data()?['role'] != UserRole.student.name) throw invalid;
      await _db.collection('users').doc(me.uid).update({
        'childIds': FieldValue.arrayUnion([id]),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw invalid;
      rethrow;
    }
    _currentUser = me.withChildIds({...me.childIds, id}.toList());
    notifyListeners();
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }
}
