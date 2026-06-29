import 'package:flutter/material.dart';

enum RoomMapItemType { room, corridor, utility, entrance }

enum RoomMapDoorSide { none, top, right, bottom, left }

enum RoomMapDoorPosition { start, center, end }

enum RoomMapFacilityKind {
  none,
  toilet,
  extinguisher,
  waterPurifier,
  microwave,
  fridge,
  vacuum,
}

class RoomMapLayout {
  final String title;
  final double width;
  final double height;
  final bool fitToWidth;
  final List<RoomMapItem> items;

  const RoomMapLayout({
    this.title = '연습실 도면',
    required this.width,
    required this.height,
    this.fitToWidth = true,
    required this.items,
  });

  factory RoomMapLayout.fromMap(Map<String, dynamic> map) {
    final savedTitle = map['title']?.toString();
    return RoomMapLayout(
      title: savedTitle == null ||
              savedTitle == '연습실 도면' ||
              savedTitle == '공실을 눌러 방문예약을 신청하세요'
          ? defaultRoomMapLayout.title
          : savedTitle,
      width: (map['width'] as num?)?.toDouble() ?? defaultRoomMapLayout.width,
      height:
          (map['height'] as num?)?.toDouble() ?? defaultRoomMapLayout.height,
      fitToWidth: map['fitToWidth'] is bool ? map['fitToWidth'] as bool : true,
      items: (map['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RoomMapItem.fromMap)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'width': width,
      'height': height,
      'title': title,
      'fitToWidth': fitToWidth,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  RoomMapLayout copyWith({
    String? title,
    double? width,
    double? height,
    bool? fitToWidth,
    List<RoomMapItem>? items,
  }) {
    return RoomMapLayout(
      title: title ?? this.title,
      width: width ?? this.width,
      height: height ?? this.height,
      fitToWidth: fitToWidth ?? this.fitToWidth,
      items: items ?? this.items,
    );
  }
}

class RoomMapItem {
  final String id;
  final RoomMapItemType type;
  final String label;
  final String? roomId;
  final int? roomNumber;
  final RoomMapFacilityKind facilityKind;
  final double x;
  final double y;
  final double width;
  final double height;
  final double fontSize;
  final RoomMapDoorSide doorSide;
  final RoomMapDoorPosition doorPosition;

  const RoomMapItem({
    required this.id,
    required this.type,
    required this.label,
    this.roomId,
    this.roomNumber,
    this.facilityKind = RoomMapFacilityKind.none,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.fontSize = 14,
    this.doorSide = RoomMapDoorSide.none,
    this.doorPosition = RoomMapDoorPosition.center,
  });

  factory RoomMapItem.fromMap(Map<String, dynamic> map) {
    return RoomMapItem(
      id: map['id']?.toString() ?? UniqueKey().toString(),
      type: _itemTypeFromString(map['type']?.toString()),
      label: map['label']?.toString() ?? '',
      roomId: map['roomId']?.toString(),
      roomNumber: (map['roomNumber'] as num?)?.toInt(),
      facilityKind: _facilityKindFromString(map['facilityKind']?.toString()),
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 80,
      height: (map['height'] as num?)?.toDouble() ?? 56,
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14,
      doorSide: _doorSideFromString(map['doorSide']?.toString()),
      doorPosition: _doorPositionFromString(map['doorPosition']?.toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'label': label,
      if (roomId != null && roomId!.isNotEmpty) 'roomId': roomId,
      if (roomNumber != null) 'roomNumber': roomNumber,
      'facilityKind': facilityKind.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'fontSize': fontSize,
      'doorSide': doorSide.name,
      'doorPosition': doorPosition.name,
    };
  }

  RoomMapItem copyWith({
    String? id,
    RoomMapItemType? type,
    String? label,
    String? roomId,
    bool clearRoomId = false,
    int? roomNumber,
    bool clearRoomNumber = false,
    RoomMapFacilityKind? facilityKind,
    double? x,
    double? y,
    double? width,
    double? height,
    double? fontSize,
    RoomMapDoorSide? doorSide,
    RoomMapDoorPosition? doorPosition,
  }) {
    return RoomMapItem(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      roomId: clearRoomId ? null : roomId ?? this.roomId,
      roomNumber: clearRoomNumber ? null : roomNumber ?? this.roomNumber,
      facilityKind: facilityKind ?? this.facilityKind,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      doorSide: doorSide ?? this.doorSide,
      doorPosition: doorPosition ?? this.doorPosition,
    );
  }
}

RoomMapItemType _itemTypeFromString(String? value) {
  return RoomMapItemType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => RoomMapItemType.utility,
  );
}

RoomMapDoorSide _doorSideFromString(String? value) {
  return RoomMapDoorSide.values.firstWhere(
    (side) => side.name == value,
    orElse: () => RoomMapDoorSide.none,
  );
}

RoomMapDoorPosition _doorPositionFromString(String? value) {
  return RoomMapDoorPosition.values.firstWhere(
    (position) => position.name == value,
    orElse: () => RoomMapDoorPosition.center,
  );
}

RoomMapFacilityKind _facilityKindFromString(String? value) {
  return RoomMapFacilityKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => RoomMapFacilityKind.none,
  );
}

const defaultRoomMapLayout = RoomMapLayout(
  title: '공실을 눌러 방문 예약을 신청하세요',
  width: 380,
  height: 560,
  items: [
    RoomMapItem(
      id: 'room-5',
      type: RoomMapItemType.room,
      label: '5번',
      roomNumber: 5,
      x: 34,
      y: 64,
      width: 88,
      height: 144,
      doorSide: RoomMapDoorSide.right,
    ),
    RoomMapItem(
      id: 'room-6',
      type: RoomMapItemType.room,
      label: '6번',
      roomNumber: 6,
      x: 122,
      y: 64,
      width: 88,
      height: 66,
      doorSide: RoomMapDoorSide.bottom,
    ),
    RoomMapItem(
      id: 'room-7',
      type: RoomMapItemType.room,
      label: '7번',
      roomNumber: 7,
      x: 210,
      y: 64,
      width: 88,
      height: 66,
      doorSide: RoomMapDoorSide.bottom,
    ),
    RoomMapItem(
      id: 'lounge',
      type: RoomMapItemType.utility,
      label: '라운지\n(휴게실)',
      x: 298,
      y: 64,
      width: 58,
      height: 132,
      doorSide: RoomMapDoorSide.left,
    ),
    RoomMapItem(
      id: 'main-hall',
      type: RoomMapItemType.utility,
      label: '메이저홀',
      x: 34,
      y: 208,
      width: 122,
      height: 198,
    ),
    RoomMapItem(
      id: 'video-room',
      type: RoomMapItemType.utility,
      label: '앙상블홀',
      x: 34,
      y: 406,
      width: 122,
      height: 92,
      doorSide: RoomMapDoorSide.right,
    ),
    RoomMapItem(
      id: 'room-4',
      type: RoomMapItemType.room,
      label: '4번',
      roomNumber: 4,
      x: 156,
      y: 208,
      width: 78,
      height: 66,
      doorSide: RoomMapDoorSide.right,
    ),
    RoomMapItem(
      id: 'room-3',
      type: RoomMapItemType.room,
      label: '3번',
      roomNumber: 3,
      x: 156,
      y: 274,
      width: 78,
      height: 66,
      doorSide: RoomMapDoorSide.right,
    ),
    RoomMapItem(
      id: 'room-2',
      type: RoomMapItemType.room,
      label: '2번',
      roomNumber: 2,
      x: 156,
      y: 340,
      width: 78,
      height: 66,
      doorSide: RoomMapDoorSide.right,
    ),
    RoomMapItem(
      id: 'room-1',
      type: RoomMapItemType.room,
      label: '1번',
      roomNumber: 1,
      x: 156,
      y: 406,
      width: 78,
      height: 92,
      doorSide: RoomMapDoorSide.right,
    ),
    RoomMapItem(
      id: 'room-8',
      type: RoomMapItemType.room,
      label: '8번',
      roomNumber: 8,
      x: 298,
      y: 196,
      width: 58,
      height: 66,
      doorSide: RoomMapDoorSide.left,
    ),
    RoomMapItem(
      id: 'room-9',
      type: RoomMapItemType.room,
      label: '9번',
      roomNumber: 9,
      x: 298,
      y: 262,
      width: 58,
      height: 66,
      doorSide: RoomMapDoorSide.left,
    ),
    RoomMapItem(
      id: 'room-10',
      type: RoomMapItemType.room,
      label: '10번',
      roomNumber: 10,
      x: 298,
      y: 328,
      width: 58,
      height: 66,
      doorSide: RoomMapDoorSide.left,
    ),
    RoomMapItem(
      id: 'room-11',
      type: RoomMapItemType.room,
      label: '11번',
      roomNumber: 11,
      x: 298,
      y: 394,
      width: 58,
      height: 66,
      doorSide: RoomMapDoorSide.left,
    ),
    RoomMapItem(
      id: 'room-12',
      type: RoomMapItemType.room,
      label: '12번',
      roomNumber: 12,
      x: 298,
      y: 460,
      width: 58,
      height: 38,
      doorSide: RoomMapDoorSide.left,
    ),
    RoomMapItem(
      id: 'printer',
      type: RoomMapItemType.utility,
      label: '프린터',
      x: 34,
      y: 498,
      width: 42,
      height: 38,
    ),
    RoomMapItem(
      id: 'desk',
      type: RoomMapItemType.utility,
      label: '책상',
      x: 76,
      y: 498,
      width: 36,
      height: 38,
    ),
    RoomMapItem(
      id: 'counter',
      type: RoomMapItemType.utility,
      label: '현관',
      x: 190,
      y: 516,
      width: 76,
      height: 30,
    ),
    RoomMapItem(
      id: 'shoe-rack',
      type: RoomMapItemType.utility,
      label: '신발장',
      x: 284,
      y: 516,
      width: 72,
      height: 30,
    ),
    RoomMapItem(
      id: 'entrance',
      type: RoomMapItemType.entrance,
      label: '출입문',
      x: 118,
      y: 520,
      width: 64,
      height: 26,
      doorSide: RoomMapDoorSide.bottom,
    ),
    RoomMapItem(
      id: 'corridor-main',
      type: RoomMapItemType.corridor,
      label: '복도',
      x: 234,
      y: 130,
      width: 64,
      height: 368,
    ),
    RoomMapItem(
      id: 'corridor-top',
      type: RoomMapItemType.corridor,
      label: '복도',
      x: 122,
      y: 130,
      width: 176,
      height: 78,
    ),
  ],
);
