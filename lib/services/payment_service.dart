import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/contract.dart';
import 'package:music_room_app/models/payment.dart';

final paymentServiceProvider = Provider((ref) => PaymentService());

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Payment>> getPaymentsByMonth(String month) {
    // month format: yyyy-MM
    return _firestore
        .collection('payments')
        .where('dueDate', isGreaterThanOrEqualTo: '$month-01')
        .where('dueDate', isLessThanOrEqualTo: '$month-31')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<int> generateMonthlyPayments(String month) async {
    // month format: yyyy-MM
    final parts = month.split('-');
    if (parts.length != 2) return 0;
    
    final year = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    
    // 해당 월의 마지막 날 계산 (다음 달의 0일은 이번 달의 말일)
    final lastDayOfMonth = DateTime(year, m + 1, 0).day;

    final contractsSnapshot = await _firestore
        .collection('contracts')
        .where('status', isEqualTo: 'active')
        .get();

    final activeContractsCount = contractsSnapshot.docs.length;
    int count = 0;
    int duplicateCount = 0;

    for (var doc in contractsSnapshot.docs) {
      final contract = Contract.fromMap(doc.data(), doc.id);
      
      // 납부일이 해당 월의 말일을 초과하면 말일로 조정
      final actualDay = contract.paymentDueDate > lastDayOfMonth 
          ? lastDayOfMonth 
          : contract.paymentDueDate;
          
      final dueDate = '$month-${actualDay.toString().padLeft(2, '0')}';
      
      // 중복 체크 (해당 계약의 해당 월 납부 문서가 이미 있는지)
      final existing = await _firestore
          .collection('payments')
          .where('contractId', isEqualTo: contract.contractId)
          .where('dueDate', isEqualTo: dueDate)
          .get();

      if (existing.docs.isEmpty) {
        final paymentId = 'pay_${contract.contractId}_${month.replaceAll('-', '')}';
        final payment = Payment(
          paymentId: paymentId,
          contractId: contract.contractId,
          userId: contract.userId,
          roomId: contract.roomId,
          amount: contract.monthlyFee,
          dueDate: dueDate,
          status: 'unpaid',
        );

        await _firestore.collection('payments').doc(paymentId).set(payment.toMap());
        count++;
      } else {
        duplicateCount++;
      }
    }

    debugPrint('[PaymentGen] Month: $month');
    debugPrint('[PaymentGen] Active Contracts: $activeContractsCount');
    debugPrint('[PaymentGen] Skipped (Duplicates): $duplicateCount');
    debugPrint('[PaymentGen] Created: $count');

    return count;
  }

  Future<void> updatePaymentStatus(String paymentId, String status, {String? paidDate}) async {
    final updates = <String, dynamic>{'status': status};
    if (paidDate != null) {
      updates['paidDate'] = paidDate;
    }
    await _firestore.collection('payments').doc(paymentId).update(updates);
  }

  Stream<List<Payment>> getUnpaidPayments() {
    return _firestore
        .collection('payments')
        .where('status', whereIn: ['unpaid', 'overdue'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<Payment>> getPaymentsByUser(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final payments = snapshot.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();
      // dueDate 기준 최신순 정렬
      payments.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return payments;
    });
  }
}
