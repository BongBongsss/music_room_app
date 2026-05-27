import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    await _firestore.collection('settings').doc('info').set(settings, SetOptions(merge: true));
  }
}
