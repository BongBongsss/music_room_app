class Payment {
  final String paymentId;
  final String contractId;
  final String userId;
  final String roomId;
  final int amount;
  final String dueDate; // yyyy-MM-dd
  final String? paidDate; // yyyy-MM-dd
  final String status; // unpaid, paid, overdue
  final String? memo;

  Payment({
    required this.paymentId,
    required this.contractId,
    required this.userId,
    required this.roomId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    required this.status,
    this.memo,
  });

  factory Payment.fromMap(Map<String, dynamic> map, String id) {
    return Payment(
      paymentId: id,
      contractId: map['contractId'] ?? '',
      userId: map['userId'] ?? '',
      roomId: map['roomId'] ?? '',
      amount: map['amount'] ?? 0,
      dueDate: map['dueDate'] ?? '',
      paidDate: map['paidDate'],
      status: map['status'] ?? 'unpaid',
      memo: map['memo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contractId': contractId,
      'userId': userId,
      'roomId': roomId,
      'amount': amount,
      'dueDate': dueDate,
      'paidDate': paidDate,
      'status': status,
      'memo': memo,
    };
  }
}
