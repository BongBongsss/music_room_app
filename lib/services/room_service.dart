import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/room.dart';

final roomServiceProvider = Provider((ref) => RoomService());

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Room>> getRooms() {
    return _firestore.collection('rooms').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<Room?> getRoomById(String roomId) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    if (doc.exists) {
      return Room.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> updateRoom(Room room) async {
    await _firestore.collection('rooms').doc(room.roomId).update(room.toMap());
  }

  /// 룸 추가 기능
  /// 수정일: 2026-05-29 11:05 (룸 관리 기능 지원)
  Future<void> addRoom(Room room) async {
    await _firestore.collection('rooms').doc(room.roomId).set(room.toMap());
  }

  /// 룸 삭제 기능
  /// 수정일: 2026-05-29 11:05 (룸 관리 기능 지원)
  Future<void> deleteRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).delete();
  }

  /// 테스트용 샘플 데이터 생성
  Future<void> seedSampleRooms() async {
    final rooms = [
      Room(
        roomId: 'room_01',
        name: 'A호실 (프리미엄)',
        dimensions: '3.4 x 2.8',
        price: 450000,
        priceUnit: '원',
        deposit: 200000, 
        description: '최고급 방음 자재와 야마하 업라이트 피아노가 구비된 프리미엄 룸입니다. 개인 연습 및 레슨에 최적화되어 있습니다.',
        photos: ['https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=800'],
        features: ['야마하 피아노', '에어컨', '이중 방음', '바닥 난방'],
        status: 'vacant',
        floor: 'B1',
        createdAt: DateTime.now(),
      ),
      Room(
        roomId: 'room_02',
        name: 'B호실 (드럼/밴드)',
        dimensions: '4.5 x 3.2',
        price: 550000,
        priceUnit: '원',
        deposit: 200000, 
        description: '드럼 세트와 기본 앰프가 포함된 넓은 공간입니다. 밴드 합주나 타악기 연습이 가능합니다.',
        photos: ['https://images.unsplash.com/photo-1519892300165-cb5542fb47c7?w=800'],
        features: ['드럼 세트', '앰프 포함', '환기 시설', '전신 거울'],
        status: 'vacant',
        floor: 'B1',
        createdAt: DateTime.now(),
      ),
      Room(
        roomId: 'room_03',
        name: 'C호실 (보컬/현악기)',
        dimensions: '2.5 x 2.2',
        price: 300000,
        priceUnit: '원',
        deposit: 150000, 
        description: '아늑한 크기의 보컬 및 현악기 전용 룸입니다. 깔끔한 인테리어로 집중력 있는 연습이 가능합니다.',
        photos: ['https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?w=800'],
        features: ['방음 완비', '책상/의자', '공기청정기'],
        status: 'occupied',
        floor: 'B1',
        createdAt: DateTime.now(),
      ),
    ];

    for (var room in rooms) {
      await _firestore.collection('rooms').doc(room.roomId).set(room.toMap());
    }
  }
}
