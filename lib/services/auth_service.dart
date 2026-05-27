import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/user_model.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 유저 문서 유효성 검사 및 데이터 가져오기
  Future<UserModel> validateAndGetUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    // 1. 유저 문서가 존재하지 않는 경우
    if (!doc.exists) {
      debugPrint('[AuthService] User document not found for uid: $uid');
      await signOut();
      throw Exception('계정 정보를 찾을 수 없습니다. 관리자에게 문의하세요.');
    }

    final data = doc.data();
    // 2. 데이터가 null인 경우
    if (data == null) {
      debugPrint('[AuthService] User data is null for uid: $uid');
      await signOut();
      throw Exception('계정 정보를 찾을 수 없습니다. 관리자에게 문의하세요.');
    }

    // 3. role 필드가 없거나 비어있는 경우
    final role = data['role'] as String?;
    if (role == null || role.isEmpty) {
      debugPrint('[AuthService] Role is missing or empty for uid: $uid');
      await signOut();
      throw Exception('계정 정보를 찾을 수 없습니다. 관리자에게 문의하세요.');
    }

    // 4. status 필드가 없는 경우 Inactive 처리
    final status = data['status'] as String? ?? 'inactive';
    if (status != 'active') {
      debugPrint('[AuthService] User status is not active ($status) for uid: $uid');
      await signOut();
      throw Exception('계약이 종료된 계정입니다. 관리자에게 문의하세요.');
    }

    return UserModel.fromMap(data, doc.id);
  }

  /// 전화번호를 이메일 형식으로 변환하는 함수
  String formatPhoneToEmail(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('82')) {
      cleanPhone = '0${cleanPhone.substring(2)}';
    }
    if (cleanPhone.length != 11) {
      throw const FormatException('올바른 전화번호를 입력해주세요.');
    }
    return '$cleanPhone@yourroom.com';
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      debugPrint('[AuthService] Attempting signIn with email: $email');
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      if (credential.user != null) {
        debugPrint('[AuthService] signIn success, validating user document...');
        await validateAndGetUser(credential.user!.uid);
        debugPrint('[AuthService] User validation successful');
      }
      return credential;
    } catch (e) {
      debugPrint('[AuthService] signIn error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

