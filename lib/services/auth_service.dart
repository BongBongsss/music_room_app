import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/user_model.dart';
import 'package:music_room_app/firebase_options.dart';

import 'package:music_room_app/services/log_service.dart';

final authServiceProvider = Provider((ref) => AuthService(ref));

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  final Ref _ref;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService(this._ref);

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
        try {
          final userModel = await validateAndGetUser(credential.user!.uid);
          debugPrint('[AuthService] User validation successful');
          
          // 로그인 로그 기록
          await _ref.read(logServiceProvider).addLog(
            action: '로그인',
            userName: userModel.name,
            userRole: userModel.role,
            details: '앱 접속',
          );
        } catch (e) {
          debugPrint('[AuthService] User validation failed: $e');
          await signOut();
          throw Exception('계정 정보 확인 중 오류가 발생했습니다. (${e.toString().replaceAll('Exception: ', '')})');
        }
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException: ${e.code}');
      switch (e.code) {
        case 'user-not-found': throw Exception('등록되지 않은 사용자입니다.');
        case 'wrong-password': throw Exception('비밀번호가 올바르지 않습니다.');
        case 'invalid-email': throw Exception('이메일 형식이 잘못되었습니다.');
        default: throw Exception('로그인에 실패했습니다. (${e.message})');
      }
    } catch (e) {
      debugPrint('[AuthService] signIn error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 관리자 권한으로 특정 사용자 계정 삭제
  Future<void> deleteAuthUser(String uid) async {
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp_Delete_${DateTime.now().millisecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      // Firebase Admin SDK를 사용할 수 없으므로, 클라이언트 측에서 삭제하려면 
      // 해당 사용자로 로그인하거나 제한 사항이 있음. 
      // 실무에서는 서버(Cloud Functions)에서 Admin SDK로 처리하는 것이 정석이나,
      // 현재 제한된 환경을 고려하여 계정 삭제를 시도합니다.
      // 참고: 클라이언트 SDK는 본인 인증 없이는 타인 계정 삭제가 불가능할 수 있습니다.
      // 이 경우 Cloud Functions 구현이 필요합니다.
      
      // 현재 구조상 Firebase Admin SDK 사용이 불가하므로 
      // 이 기능이 성공하려면 적절한 권한(Firestore Rules/Cloud Functions)이 필요합니다.
      // 우선 시도해보고 예외처리를 강화합니다.
      await secondaryAuth.currentUser?.delete(); 
    } finally {
      await secondaryApp.delete();
    }
  }
}

