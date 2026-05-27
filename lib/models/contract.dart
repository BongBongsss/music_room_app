import 'package:cloud_firestore/cloud_firestore.dart';

class Contract {
  final String contractId;
  final String userId;
  final String roomId;
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd
  final int monthlyFee;
  final int paymentDueDate; // e.g., 5 for the 5th of each month
  final String paymentMethod;
  final String status; // active, expired, terminated
  final String? memo;
  final DateTime? createdAt;

  Contract({
    required this.contractId,
    required this.userId,
    required this.roomId,
    required this.startDate,
    required this.endDate,
    required this.monthlyFee,
    required this.paymentDueDate,
    required this.paymentMethod,
    required this.status,
    this.memo,
    this.createdAt,
  });

  factory Contract.fromMap(Map<String, dynamic> map, String id) {
    return Contract(
      contractId: id,
      userId: map['userId'] ?? '',
      roomId: map['roomId'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      monthlyFee: map['monthlyFee'] ?? 0,
      paymentDueDate: map['paymentDueDate'] ?? 1,
      paymentMethod: map['paymentMethod'] ?? '계좌이체',
      status: map['status'] ?? 'active',
      memo: map['memo'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'roomId': roomId,
      'startDate': startDate,
      'endDate': endDate,
      'monthlyFee': monthlyFee,
      'paymentDueDate': paymentDueDate,
      'paymentMethod': paymentMethod,
      'status': status,
      'memo': memo,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
