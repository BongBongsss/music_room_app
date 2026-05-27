import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/user_model.dart';

final userServiceProvider = Provider((ref) => UserService());

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.userId).set(user.toMap());
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.userId).update(user.toMap());
  }

  Future<void> updateFirstLogin(String uid, bool isFirstLogin) async {
    await _firestore.collection('users').doc(uid).update({
      'isFirstLogin': isFirstLogin,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 모든 고객(customer) 목록 조회
  Stream<List<UserModel>> getAllCustomers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }

  /// 특정 이메일(전화번호 기반)을 가진 유저가 이미 존재하는지 확인
  Future<bool> isUserExists(String email) async {
    final query = await _firestore
        .collection('users')
        .where('loginEmail', isEqualTo: email)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }
}
