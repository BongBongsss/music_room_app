import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/user_model.dart';
import 'package:music_room_app/models/contract.dart';
import 'package:music_room_app/models/payment.dart';
import 'package:music_room_app/screens/rooms/room_detail_screen.dart';
import 'package:music_room_app/services/contract_service.dart';
import 'package:music_room_app/services/payment_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

final userDetailProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null);
});

final userActiveContractsProvider = StreamProvider.family<List<Contract>, String>((ref, uid) {
  return ref.watch(contractServiceProvider).getActiveContractsByUser(uid);
});

final userPaymentsProvider = StreamProvider.family<List<Payment>, String>((ref, uid) {
  return ref.watch(paymentServiceProvider).getPaymentsByUser(uid);
});

class CustomerDetailScreen extends ConsumerWidget {
  final String userId;
  const CustomerDetailScreen({super.key, required this.userId});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailProvider(userId));
    final contractsAsync = ref.watch(userActiveContractsProvider(userId));
    final paymentsAsync = ref.watch(userPaymentsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('계약자 상세 정보')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('사용자를 찾을 수 없습니다.'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 기본 프로필 섹션
                _ProfileSection(user: user, onCall: () => _makePhoneCall(user.phone)),
                const SizedBox(height: 24),

                // 2. 현재 계약 정보 섹션
                const Text('현재 계약 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                contractsAsync.when(
                  data: (contracts) {
                    if (contracts.isEmpty) return const _EmptyCard(message: '현재 진행 중인 계약이 없습니다.');
                    return Column(
                      children: contracts.map((c) => _ContractCard(contract: c)).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('계약 정보 오류: $err'),
                ),
                const SizedBox(height: 24),

                // 3. 납부 내역 섹션
                const Text('납부 내역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                paymentsAsync.when(
                  data: (payments) {
                    if (payments.isEmpty) return const _EmptyCard(message: '납부 내역이 없습니다.');
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        return _PaymentListTile(payment: payments[index]);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('납부 내역 오류: $err'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('데이터 로딩 오류: $err')),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final UserModel user;
  final VoidCallback onCall;
  const _ProfileSection({required this.user, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user.phone, style: const TextStyle(color: Colors.grey)),
                  Text(user.loginEmail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              onPressed: onCall,
              icon: const Icon(Icons.phone, color: Colors.green),
              tooltip: '전화 걸기',
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractCard extends ConsumerWidget {
  final Contract contract;
  const _ContractCard({required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,###');
    final roomAsync = ref.watch(roomDetailProvider(contract.roomId));

    return Card(
      color: Colors.blue[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(contract.roomId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    const Text('계약중', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditContractDialog(context, ref, contract),
                      tooltip: '계약 수정',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            _InfoRow(label: '계약 기간', value: '${contract.startDate} ~ ${contract.endDate}'),
            _InfoRow(label: '월세', value: '${fmt.format(contract.monthlyFee)}원'),
            _InfoRow(label: '납부일', value: '매월 ${contract.paymentDueDate}일'),
            _InfoRow(label: '결제 수단', value: contract.paymentMethod),
            _InfoRow(label: '사용 악기', value: contract.instrument?.isNotEmpty == true ? contract.instrument! : '없음'),
            
            // 보증금 표시 (Room 정보를 비동기로 불러와 표시)
            roomAsync.when(
              data: (room) => room != null 
                  ? _InfoRow(label: '보증금', value: '${fmt.format(room.deposit)}원')
                  : const SizedBox.shrink(),
              loading: () => const _InfoRow(label: '보증금', value: '불러오는 중...'),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditContractDialog(BuildContext context, WidgetRef ref, Contract contract) async {
    final startDateController = TextEditingController(text: contract.startDate);
    final monthlyFeeController = TextEditingController(text: contract.monthlyFee.toString());
    final dueDateController = TextEditingController(text: contract.paymentDueDate.toString());
    final depositController = TextEditingController();
    final instrumentController = TextEditingController(text: contract.instrument ?? ''); // 악기 컨트롤러 추가

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계약 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: startDateController,
                decoration: const InputDecoration(labelText: '시작일 (yyyy-MM-dd)'),
              ),
              TextFormField(
                controller: monthlyFeeController,
                decoration: const InputDecoration(labelText: '월세 (원)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: dueDateController,
                decoration: const InputDecoration(labelText: '납부일 (일)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: depositController,
                decoration: const InputDecoration(labelText: '보증금 (원)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: instrumentController,
                decoration: const InputDecoration(labelText: '사용 악기'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              try {
                final updateData = {
                  'startDate': startDateController.text.trim(),
                  'monthlyFee': int.tryParse(monthlyFeeController.text) ?? contract.monthlyFee,
                  'paymentDueDate': int.tryParse(dueDateController.text) ?? contract.paymentDueDate,
                  'instrument': instrumentController.text.trim(), // 악기 저장
                };
                
                if (depositController.text.isNotEmpty) {
                    final deposit = int.tryParse(depositController.text);
                    if (deposit != null) {
                        await FirebaseFirestore.instance.collection('rooms').doc(contract.roomId).update({
                            'deposit': deposit,
                        });
                    }
                }

                await FirebaseFirestore.instance.collection('contracts').doc(contract.contractId).update(updateData);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 오류: $e')));
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _PaymentListTile extends StatelessWidget {
  final Payment payment;
  const _PaymentListTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final bool isPaid = payment.status == 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${payment.dueDate}분 납부'),
        subtitle: Text('${fmt.format(payment.amount)}원'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPaid ? Colors.blue[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isPaid ? '완료' : '미납',
            style: TextStyle(color: isPaid ? Colors.blue : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(message, style: const TextStyle(color: Colors.grey))),
      ),
    );
  }
}
