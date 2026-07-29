import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient;

import '../domain/roles.dart';
import 'models.dart';
import 'repos.dart';

/// Firebase owns the session; Supabase stores the Labaan profile and app data.
///
/// Firebase UIDs are deliberately kept out of the app's public models. The
/// database maps each UID to a generated UUID in `profiles.id`.
class FirebaseAuthRepo implements AuthRepo {
  FirebaseAuthRepo(
    this._supabase, {
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _google = googleSignIn ?? GoogleSignIn.instance;

  final SupabaseClient _supabase;
  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  bool _googleInitialized = false;
  String? _phoneVerificationId;
  String? _phoneLinkVerificationId;

  @override
  Stream<LbUser?> authStateChanges() =>
      _auth.authStateChanges().asyncMap(_profileFor);

  @override
  Future<LbUser?> currentUser() => _profileFor(_auth.currentUser);

  Future<LbUser?> _profileFor(User? firebaseUser) async {
    if (firebaseUser == null) return null;
    await firebaseUser.getIdToken(true);

    var row = await _supabase
        .from('profiles')
        .select()
        .eq('firebase_uid', firebaseUser.uid)
        .maybeSingle();

    if (row == null) {
      final uidFragment = firebaseUser.uid
          .replaceAll(RegExp('[^A-Za-z0-9_]'), '')
          .toLowerCase();
      final suffix = uidFragment.length > 16
          ? uidFragment.substring(0, 16)
          : uidFragment;
      try {
        row = await _supabase
            .from('profiles')
            .insert({
              'firebase_uid': firebaseUser.uid,
              'username': 'player_$suffix',
              'display_name': firebaseUser.displayName,
              'avatar_url': firebaseUser.photoURL,
              'games': <String>[],
              'has_completed_setup': false,
            })
            .select()
            .single();
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        row = await _supabase
            .from('profiles')
            .select()
            .eq('firebase_uid', firebaseUser.uid)
            .single();
      }
    }

    return _userFromFirebase(row, firebaseUser);
  }

  LbUser _userFromFirebase(Map<String, dynamic> row, User firebaseUser) {
    return LbUser(
      id: row['id'] as String,
      username: row['username'] as String,
      email: firebaseUser.email ?? '',
      phone: firebaseUser.phoneNumber,
      region: row['region'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      role: UserRole.player,
      games: ((row['games'] as List?) ?? const []).cast<String>(),
      hasCompletedSetup: (row['has_completed_setup'] as bool?) ?? false,
      isBanned: (row['is_banned'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) return;
    await _google.initialize(clientId: Firebase.app().options.iosClientId);
    _googleInitialized = true;
  }

  @override
  Future<LbUser> signInWithGoogle() async {
    await _initializeGoogle();
    final googleUser = await _google.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final profile = await _profileFor(result.user);
    if (profile == null) {
      throw FirebaseAuthException(code: 'missing-firebase-user');
    }
    return profile;
  }

  @override
  Future<LbUser> signInWithFacebook() {
    throw UnsupportedError('Facebook sign-in is not configured in Firebase.');
  }

  @override
  Future<void> requestPhoneOtp(String phoneE164) async {
    final sent = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          if (!sent.isCompleted) sent.complete();
        } catch (error, stackTrace) {
          if (!sent.isCompleted) sent.completeError(error, stackTrace);
        }
      },
      verificationFailed: (error) {
        if (!sent.isCompleted) sent.completeError(error, error.stackTrace);
      },
      codeSent: (verificationId, _) {
        _phoneVerificationId = verificationId;
        if (!sent.isCompleted) sent.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _phoneVerificationId = verificationId;
      },
    );
    await sent.future;
  }

  @override
  Future<LbUser> verifyPhoneOtp({
    required String phoneE164,
    required String token,
  }) async {
    final verificationId = _phoneVerificationId;
    if (verificationId == null) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Request a new verification code.',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: token,
    );
    final result = await _auth.signInWithCredential(credential);
    final profile = await _profileFor(result.user);
    if (profile == null) {
      throw FirebaseAuthException(code: 'missing-firebase-user');
    }
    return profile;
  }

  @override
  Future<Set<String>> linkedProviders() async {
    final user = _auth.currentUser;
    if (user == null) return const {};
    await user.reload();
    return user.providerData.map((provider) => provider.providerId).toSet();
  }

  Future<AuthCredential> _googleCredential() async {
    await _initializeGoogle();
    final googleUser = await _google.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<void> linkGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'not-signed-in');
    if (user.providerData.any((item) => item.providerId == 'google.com')) {
      return;
    }
    await user.linkWithCredential(await _googleCredential());
  }

  @override
  Future<void> requestPhoneLink(String phoneE164) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'not-signed-in');
    final sent = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      verificationCompleted: (credential) async {
        try {
          await user.linkWithCredential(credential);
          if (!sent.isCompleted) sent.complete();
        } catch (error, stackTrace) {
          if (!sent.isCompleted) sent.completeError(error, stackTrace);
        }
      },
      verificationFailed: (error) {
        if (!sent.isCompleted) sent.completeError(error, error.stackTrace);
      },
      codeSent: (verificationId, _) {
        _phoneLinkVerificationId = verificationId;
        if (!sent.isCompleted) sent.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _phoneLinkVerificationId = verificationId;
      },
    );
    await sent.future;
  }

  @override
  Future<void> verifyPhoneLink({
    required String phoneE164,
    required String token,
  }) async {
    final user = _auth.currentUser;
    final verificationId = _phoneLinkVerificationId;
    if (user == null) throw FirebaseAuthException(code: 'not-signed-in');
    if (verificationId == null) {
      throw FirebaseAuthException(code: 'missing-verification-id');
    }
    await user.linkWithCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: token,
      ),
    );
    _phoneLinkVerificationId = null;
  }

  @override
  Future<void> requestEmailChange(String email) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'not-signed-in');
    await user.verifyBeforeUpdateEmail(email);
  }

  @override
  Future<void> completeFirstRunSetup({
    required String username,
    required String region,
    required List<String> games,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-signed-in');
    }
    await _supabase
        .from('profiles')
        .update({
          'username': username,
          'region': region,
          'games': games,
          'has_completed_setup': true,
        })
        .eq('firebase_uid', user.uid);
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _google.signOut()]);
  }
}
