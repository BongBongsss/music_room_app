import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/notice.dart';

final noticeServiceProvider = Provider((ref) => NoticeService());

final noticesProvider = StreamProvider<List<Notice>>((ref) {
  return ref.watch(noticeServiceProvider).getNotices();
});

class NoticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Notice>> getNotices() {
    debugPrint('Firestore 요청 시작: notices 컬렉션');
    return _firestore
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('Firestore 응답 수신: ${snapshot.docs.length}개');
      return snapshot.docs.map((doc) => Notice.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addNotice(Notice notice) async {
    await _firestore.collection('notices').add(notice.toMap());
  }

  Future<void> updateNotice(Notice notice) async {
    await _firestore.collection('notices').doc(notice.noticeId).update(notice.toMap());
  }

  Future<void> togglePin(Notice notice) async {
    await _firestore.collection('notices').doc(notice.noticeId).update({
      'isPinned': !notice.isPinned,
    });
  }

  Future<void> deleteNotice(String noticeId) async {
    await _firestore.collection('notices').doc(noticeId).delete();
  }
}
