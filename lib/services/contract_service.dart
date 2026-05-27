import 'package:cloud_firestore/cloud_firestore.dart';
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
}
