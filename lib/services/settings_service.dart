import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/room_map_layout.dart';

final settingsServiceProvider = Provider((ref) => SettingsService());

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _defaultSettings = {
    'visitAvailableDays': [1, 2, 3, 4, 5],
    'visitStartTime': '09:00',
    'visitEndTime': '21:00',
    'kakaoOpenChatUrl': '',
  };

  Future<Map<String, dynamic>> getVisitSettings() async {
    final doc = await _firestore.collection('settings').doc('info').get();
    if (doc.exists) {
      return {..._defaultSettings, ...doc.data()!};
    }
    return _defaultSettings;
  }

  Future<String?> getKakaoOpenChatUrl() async {
    final settings = await getVisitSettings();
    return settings['kakaoOpenChatUrl'] as String?;
  }

  Stream<Map<String, dynamic>> watchVisitSettings() {
    return _firestore.collection('settings').doc('info').snapshots().map((doc) {
      if (doc.exists) {
        return {..._defaultSettings, ...doc.data()!};
      }
      return _defaultSettings;
    });
  }

  Future<void> updateVisitSettings(Map<String, dynamic> settings) async {
    await _firestore
        .collection('settings')
        .doc('info')
        .set(settings, SetOptions(merge: true));
  }

  Stream<RoomMapLayout> watchRoomMapLayout() {
    return _firestore.collection('settings').doc('info').snapshots().map((doc) {
      final data = doc.data();
      final mapData = data?['roomMapLayout'];
      if (mapData is Map<String, dynamic>) {
        final layout = RoomMapLayout.fromMap(mapData);
        if (layout.items.isNotEmpty) return layout;
      }
      return defaultRoomMapLayout;
    });
  }

  Future<RoomMapLayout> getRoomMapLayout() async {
    final doc = await _firestore.collection('settings').doc('info').get();
    final mapData = doc.data()?['roomMapLayout'];
    if (mapData is Map<String, dynamic>) {
      final layout = RoomMapLayout.fromMap(mapData);
      if (layout.items.isNotEmpty) return layout;
    }
    return defaultRoomMapLayout;
  }

  Future<void> updateRoomMapLayout(RoomMapLayout layout) async {
    await _firestore.collection('settings').doc('info').set({
      'roomMapLayout': layout.toMap(),
      'updatedAt': DateTime.now(),
    }, SetOptions(merge: true));
  }

  // 데이터 구조를 새로운 시간 설정에 맞게 가져오기/저장하기 위한 헬퍼
  // (실제 데이터 마이그레이션은 Firestore 콘솔에서 수동으로 하거나, 앱 실행 시점에 보완)
}
