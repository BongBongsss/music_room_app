import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/visit.dart';

final visitServiceProvider = Provider((ref) => VisitService());

class VisitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 방문 예약 신청 저장 (중복 체크 포함)
  Future<void> requestVisit(Visit visit) async {
    try {
      final conflictQuery = await _firestore
          .collection('visits')
          .where('roomId', isEqualTo: visit.roomId)
          .where('visitDate', isEqualTo: visit.visitDate)
          .where('visitTime', isEqualTo: visit.visitTime)
          .where('status', whereIn: ['pending', 'approved', 'confirmed'])
          .limit(1)
          .get();

      if (conflictQuery.docs.isNotEmpty) {
        throw Exception('이미 같은 시간대 예약이 존재합니다.');
      }

      final docRef = _firestore.collection('visits').doc();
      final visitWithId = Visit(
        visitId: docRef.id,
        userId: visit.userId,
        userName: visit.userName,
        userPhone: visit.userPhone,
        roomId: visit.roomId,
        visitDate: visit.visitDate,
        visitTime: visit.visitTime,
        status: 'pending',
        memo: visit.memo,
        createdAt: DateTime.now(),
      );
      await docRef.set(visitWithId.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// 특정 사용자의 방문 예약 목록 조회
  Stream<List<Visit>> getUserVisits(String userId) {
    return _firestore
        .collection('visits')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Visit.fromMap(doc.data(), doc.id)).toList());
  }

  /// 모든 방문 예약 목록 조회 (운영자용)
  Stream<List<Visit>> getAllVisits() {
    return _firestore
        .collection('visits')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Visit.fromMap(doc.data(), doc.id)).toList());
  }

  /// 내부용 1회 업데이트 함수
  Future<void> _updateVisitStatusOnce(String visitId, String status) async {
    await _firestore.collection('visits').doc(visitId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));
  }

  /// 방문 예약 상태 업데이트 (재시도 로직 포함)
  Future<void> updateVisitStatus(String visitId, String status) async {
    if (visitId.trim().isEmpty) {
      throw Exception('유효하지 않은 방문 예약 ID입니다.');
    }

    try {
      try {
        await _updateVisitStatusOnce(visitId, status);
      } on TimeoutException {
        // 짧은 대기 후 1회 재시도
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _updateVisitStatusOnce(visitId, status);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('권한이 없어 상태를 변경할 수 없습니다.');
      }
      if (e.code == 'unavailable') {
        throw Exception('네트워크가 불안정합니다. 잠시 후 다시 시도해주세요.');
      }
      throw Exception('상태 변경 실패: ${e.code}');
    } on TimeoutException {
      throw Exception('네트워크 지연으로 상태 변경이 지연되고 있습니다. 잠시 후 다시 시도해주세요.');
    } catch (e) {
      rethrow;
    }
  }
}
