import 'package:cloud_firestore/cloud_firestore.dart';

class Notice {
  final String noticeId;
  final String title;
  final String content;
  final bool isPinned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Notice({
    required this.noticeId,
    required this.title,
    required this.content,
    required this.isPinned,
    this.createdAt,
    this.updatedAt,
  });

  factory Notice.fromMap(Map<String, dynamic> map, String id) {
    return Notice(
      noticeId: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      isPinned: map['isPinned'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'isPinned': isPinned,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
