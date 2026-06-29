import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/contract.dart';

final contractServiceProvider = Provider((ref) => ContractService());

final activeContractsProvider = StreamProvider<List<Contract>>((ref) {
  return ref.watch(contractServiceProvider).getActiveContracts();
});

class ContractService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 활성 계약 목록 조회
  Stream<List<Contract>> getActiveContracts() {
    return _firestore
        .collection('contracts')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Contract.fromMap(doc.data(), doc.id)).toList());
  }

  /// 특정 룸의 현재 활성 계약 조회
  Future<Contract?> getActiveContractByRoom(String roomId) async {
    final query = await _firestore
        .collection('contracts')
        .where('roomId', isEqualTo: roomId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      return Contract.fromMap(query.docs.first.data(), query.docs.first.id);
    }
    return null;
  }

  /// 특정 사용자의 활성 계약 목록 조회
  Stream<List<Contract>> getActiveContractsByUser(String userId) {
    return _firestore
        .collection('contracts')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Contract.fromMap(doc.data(), doc.id)).toList());
  }

  /// 특정 사용자의 활성 계약 roomId 목록 조회
  Future<Set<String>> getActiveRoomIdsByUser(String userId) async {
    final query = await _firestore
        .collection('contracts')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    return query.docs.map((doc) => doc.data()['roomId'] as String).toSet();
  }

  /// 특정 룸의 전체 계약 이력 조회
  Stream<List<Contract>> getContractHistoryByRoom(String roomId) {
    return _firestore
        .collection('contracts')
        .where('roomId', isEqualTo: roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Contract.fromMap(doc.data(), doc.id)).toList());
  }

  /// 계약 해지 처리
  /// 수정일: 2026-05-29 11:30 (상태 업데이트 로직 보강)
  Future<void> terminateContract({
    required String contractId,
    required String userId,
    required String roomId,
  }) async {
    debugPrint('[ContractService] Terminating contract: $contractId, roomId: $roomId, userId: $userId');
    
    final batch = _firestore.batch();

    // 1. 계약 상태 변경
    batch.update(_firestore.collection('contracts').doc(contractId), {
      'status': 'terminated',
    });

    // 2. 룸 상태 변경 (강제 업데이트)
    batch.update(_firestore.collection('rooms').doc(roomId), {
      'status': 'vacant',
    });

    // 3. 사용자 정보 업데이트 (활성 계약 ID 제거)
    batch.update(_firestore.collection('users').doc(userId), {
      'contractId': null,
    });

    try {
      await batch.commit();
      debugPrint('[ContractService] Contract terminated successfully.');
    } catch (e) {
      debugPrint('[ContractService] Error terminating contract: $e');
      throw Exception('계약 해지 처리 중 오류가 발생했습니다: $e');
    }
  }
}
