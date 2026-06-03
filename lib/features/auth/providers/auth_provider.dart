import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../core/services/notification_service.dart';

enum AuthRole { user, dentist, none }

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get firebaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  AuthRole _role = AuthRole.none;
  AuthRole get role => _role;

  bool _loading = false;
  bool get loading => _loading;

  bool _initialized = false;
  bool get initialized => _initialized;

  AuthProvider() {
    // iPadOS 26 gibi yeni/beta OS'lerde Firebase yavaş kalabilir;
    // 6 saniyede init olmazsa login'e zorla
    Future.delayed(const Duration(seconds: 6), () {
      if (!_initialized) {
        _userModel = null;
        _role = AuthRole.none;
        _initialized = true;
        notifyListeners();
      }
    });

    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _userModel = null;
        _role = AuthRole.none;
        _initialized = true;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final userDoc = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (userDoc.exists) {
        _userModel = UserModel.fromMap(userDoc.data()!, uid);
        _role = AuthRole.user;
        NotificationService.saveTokenForUser(uid);
      } else {
        final clinicDoc = await _db
            .collection('clinics')
            .where('ownerId', isEqualTo: uid)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));
        if (clinicDoc.docs.isNotEmpty) {
          _role = AuthRole.dentist;
          NotificationService.saveTokenForClinic(clinicDoc.docs.first.id);
        } else {
          _role = AuthRole.user;
        }
      }
    } catch (_) {
      _role = AuthRole.user;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<String?> signUpUser({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      _loading = true;
      notifyListeners();
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = UserModel(
        id: cred.user!.uid,
        name: name,
        email: email,
        phone: phone,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(cred.user!.uid).set(user.toMap());
      _userModel = user;
      _role = AuthRole.user;
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _loading = true;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reloadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      _userModel = UserModel.fromMap(userDoc.data()!, uid);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _initialized = false;
    _role = AuthRole.none;
    _userModel = null;
    await _auth.signOut();
  }
}
