import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppUser? _currentUser;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  bool get isLoggedIn => _currentUser != null;
  UserRole get userRole => _currentUser?.role ?? UserRole.student;
  AppUser? get currentUser => _currentUser;

  Future<void> _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
    } else {
      final doc = await _db.collection('users').doc(firebaseUser.uid).get();
      _currentUser = AppUser.fromMap(firebaseUser.uid, doc.data() ?? {});
    }
    notifyListeners();
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
    await _db.collection('users').doc(uid).set(
      AppUser(uid: uid, name: name, email: email, role: role).toMap(),
    );
  }

  Future<void> signOut() => _auth.signOut();
}
