import 'package:cloud_firestore/cloud_firestore.dart';

class Visit {
  final String visitId;
  final String? userId;
  final String userName;
  final String userPhone;
  final String roomId;
  final String visitDate; // yyyy-MM-dd
  final String visitTime; // HH:mm
  final String status; // pending, confirmed, cancelled, completed
  final String? memo;
  final DateTime? createdAt;

  Visit({
    required this.visitId,
    this.userId,
    required this.userName,
    required this.userPhone,
    required this.roomId,
    required this.visitDate,
    required this.visitTime,
    required this.status,
    this.memo,
    this.createdAt,
  });

  factory Visit.fromMap(Map<String, dynamic> map, String id) {
    return Visit(
      visitId: id,
      userId: map['userId'],
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      roomId: map['roomId'] ?? '',
      visitDate: map['visitDate'] ?? '',
      visitTime: map['visitTime'] ?? '',
      status: map['status'] ?? 'pending',
      memo: map['memo'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'roomId': roomId,
      'visitDate': visitDate,
      'visitTime': visitTime,
      'status': status,
      'memo': memo,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
