import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final logServiceProvider = Provider((ref) => LogService());

class LogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 로그 남기기
  Future<void> addLog({
    required String action,
    required String userName,
    required String userRole,
    String? details,
  }) async {
    try {
      await _firestore.collection('logs').add({
        'action': action,
        'userName': userName,
        'userRole': userRole,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // 로그 저장 실패는 앱 실행에 지장을 주지 않도록 출력만 함
      debugPrint('Log save error: $e');
    }
  }

  // 로그 목록 가져오기 (최신순 100개)
  Stream<List<Map<String, dynamic>>> getLogs() {
    return _firestore
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }
}
