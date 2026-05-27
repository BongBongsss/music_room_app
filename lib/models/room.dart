import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String roomId;
  final String name;
  final double size;
  final String sizeUnit;
  final int price;
  final String priceUnit;
  final String description;
  final List<String> photos;
  final List<String> features;
  final String status; // vacant, occupied
  final String floor;
  final String? adminMemo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Room({
    required this.roomId,
    required this.name,
    required this.size,
    required this.sizeUnit,
    required this.price,
    required this.priceUnit,
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
      size: (map['size'] as num?)?.toDouble() ?? 0.0,
      sizeUnit: map['sizeUnit'] ?? 'm^2',
      price: map['price'] ?? 0,
      priceUnit: map['priceUnit'] ?? '원',
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
      'size': size,
      'sizeUnit': sizeUnit,
      'price': price,
      'priceUnit': priceUnit,
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
