import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String roomId;
  final String name;
  final String dimensions; // 가로 x 세로 (예: 3.4 x 2.8)
  final int price;
  final String priceUnit;
  final int deposit;
  final String description;
  final List<String> photos;
  final List<String> features;
  final String status;
  final String floor;
  final String? adminMemo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Room({
    required this.roomId,
    required this.name,
    required this.dimensions,
    required this.price,
    required this.priceUnit,
    required this.deposit,
    required this.description,
    required this.photos,
    required this.features,
    required this.status,
    required this.floor,
    this.adminMemo,
    this.createdAt,
    this.updatedAt,
  });

  factory Room.fromMap(Map<String, dynamic> map, String id) {
    return Room(
      roomId: id,
      name: map['name'] ?? '',
      dimensions: map['dimensions'] ?? '',
      price: map['price'] ?? 0,
      priceUnit: map['priceUnit'] ?? '원',
      deposit: map['deposit'] ?? 0,
      description: map['description'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      features: List<String>.from(map['features'] ?? []),
      status: map['status'] ?? 'vacant',
      floor: map['floor'] ?? '',
      adminMemo: map['adminMemo'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dimensions': dimensions,
      'price': price,
      'priceUnit': priceUnit,
      'deposit': deposit,
      'description': description,
      'photos': photos,
      'features': features,
      'status': status,
      'floor': floor,
      'adminMemo': adminMemo,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
