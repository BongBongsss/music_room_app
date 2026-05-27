import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/payment.dart';

final statisticsServiceProvider = Provider((ref) => StatisticsService());

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getMonthlyStats(String month) async {
    // month format: yyyy-MM
    final monthStart = '$month-01';
    final monthEnd = '$month-31';

    // 1. ?좏깮???붿뿉 ?좏슚?덇퀬 inactive媛 ?꾨땶 紐⑤뱺 怨꾩빟 怨꾩궛
    final contractsSnapshot = await _firestore.collection('contracts').get();

    int totalExpected = 0;
    for (var doc in contractsSnapshot.docs) {
      final data = doc.data();
      final startDate = data['startDate'] as String? ?? '';
      final endDate = data['endDate'] as String? ?? '';
      final status = data['status'] as String? ?? '';

      // 조건: (startDate <= 선택월 말일 AND endDate >= 선택월 1일) AND status in [active, expired, terminated]
      final isInSelectedMonthRange =
          startDate.compareTo(monthEnd) <= 0 &&
          endDate.compareTo(monthStart) >= 0;

      if (isInSelectedMonthRange && ['active', 'expired', 'terminated'].contains(status)) {
        totalExpected += (data['monthlyFee'] as num? ?? 0).toInt();
      }
    }

    // 2. ?대떦 ?붿쓽 ?⑸? ?댁뿭 議고쉶
    final paymentsSnapshot = await _firestore
        .collection('payments')
        .where('dueDate', isGreaterThanOrEqualTo: monthStart)
        .where('dueDate', isLessThanOrEqualTo: monthEnd)
        .get();

    final payments = paymentsSnapshot.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();

    int totalPaid = 0;
    int totalUnpaid = 0;
    int unpaidCount = 0;

    for (var payment in payments) {
      if (payment.status == 'paid') {
        totalPaid += payment.amount;
      } else {
        totalUnpaid += payment.amount;
        unpaidCount++;
      }
    }

    final double delinquencyRate = payments.isEmpty ? 0 : (unpaidCount / payments.length) * 100;

    return {
      'totalExpected': totalExpected,
      'totalPaid': totalPaid,
      'totalUnpaid': totalUnpaid,
      'delinquencyRate': delinquencyRate,
      'paymentCount': payments.length,
      'unpaidCount': unpaidCount,
      'payments': payments,
    };
  }

  Future<List<Map<String, dynamic>>> getLastSixMonthsStats() async {
    final List<Map<String, dynamic>> stats = [];
    final now = DateTime.now();

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('dueDate', isGreaterThanOrEqualTo: '$month-01')
          .where('dueDate', isLessThanOrEqualTo: '$month-31')
          .get();

      int monthlyTotal = 0;
      for (var doc in paymentsSnapshot.docs) {
        final payment = Payment.fromMap(doc.data(), doc.id);
        if (payment.status == 'paid') {
          monthlyTotal += payment.amount;
        }
      }

      stats.add({
        'month': month,
        'amount': monthlyTotal,
      });
    }

    return stats;
  }
}



