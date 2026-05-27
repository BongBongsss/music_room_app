import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/payment.dart';
import 'package:music_room_app/services/payment_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PaymentManagementScreen extends ConsumerStatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  ConsumerState<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends ConsumerState<PaymentManagementScreen> {
  bool _isGenerating = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(settings: initSettings);
  }

  Future<void> _generatePayments() async {
    setState(() => _isGenerating = true);
    try {
      final now = DateTime.now();
      final month = DateFormat('yyyy-MM').format(now);
      final count = await ref.read(paymentServiceProvider).generateMonthlyPayments(month);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count건의 이번 달 납부 문서가 생성되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('생성 중 오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _sendNotification(String userName) async {
    const androidDetails = AndroidNotificationDetails(
      'payment_reminder',
      '납부 알림',
      channelDescription: '납부 경과 알림을 위한 채널입니다.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: '납부 알림',
      body: '$userName님의 납부일이 지났습니다. 확인 부탁드립니다.',
      notificationDetails: notificationDetails,
    );
  }

  Future<void> _handleConfirmPayment(Payment payment) async {
    try {
      await ref.read(paymentServiceProvider).updatePaymentStatus(
            payment.paymentId,
            'paid',
            paidDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('납부가 확인되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('납부 확인에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unpaidPaymentsAsync = ref.watch(
      StreamProvider((ref) => ref.watch(paymentServiceProvider).getUnpaidPayments()),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('납부 관리'),
        actions: [
          IconButton(
            onPressed: _isGenerating ? null : _generatePayments,
            icon: _isGenerating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.note_add),
            tooltip: '이번 달 납부 문서 생성',
          ),
        ],
      ),
      body: unpaidPaymentsAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return const Center(child: Text('미납 내역이 없습니다.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _PaymentListItem(
                payment: payment,
                onNotify: () => _sendNotification('고객'),
                onConfirm: () => _handleConfirmPayment(payment),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('오류: $err')),
      ),
    );
  }
}

class _PaymentListItem extends StatelessWidget {
  final Payment payment;
  final VoidCallback onNotify;
  final VoidCallback onConfirm;

  const _PaymentListItem({
    required this.payment,
    required this.onNotify,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${payment.dueDate} 납부건',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: payment.status == 'overdue' ? Colors.red[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    payment.status == 'overdue' ? '연체' : '미납',
                    style: TextStyle(
                      color: payment.status == 'overdue' ? Colors.red : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('금액: ${NumberFormat('#,###').format(payment.amount)}원'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onNotify,
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: const Text('알림 발송'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onConfirm,
                  child: const Text('납부 확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
