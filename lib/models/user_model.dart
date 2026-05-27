import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String phone;
  final String loginEmail;
  final String role; // customer, admin
  final String status; // active, inactive
  final String? contractId;
  final bool isFirstLogin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.phone,
    required this.loginEmail,
    required this.role,
    required this.status,
    this.contractId,
    required this.isFirstLogin,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      userId: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      loginEmail: map['loginEmail'] ?? '',
      role: map['role'] ?? 'customer',
      status: map['status'] ?? 'active',
      contractId: map['contractId'],
      isFirstLogin: map['isFirstLogin'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'loginEmail': loginEmail,
      'role': role,
      'status': status,
      'contractId': contractId,
      'isFirstLogin': isFirstLogin,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
