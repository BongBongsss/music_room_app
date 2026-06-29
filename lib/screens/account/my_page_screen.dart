import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/models/contract.dart';
import 'package:music_room_app/models/payment.dart';
import 'package:music_room_app/models/user_model.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/contract_service.dart';
import 'package:music_room_app/services/payment_service.dart';
import 'package:music_room_app/services/user_service.dart';
import 'package:intl/intl.dart';

final myPageUserProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  return ref.watch(userServiceProvider).getUser(uid);
});

final myActiveContractsProvider = StreamProvider.family<List<Contract>, String>((ref, uid) {
  return ref.watch(contractServiceProvider).getActiveContractsByUser(uid);
});

final myPaymentsProvider = StreamProvider.family<List<Payment>, String>((ref, uid) {
  return ref.watch(paymentServiceProvider).getPaymentsByUser(uid);
});

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('마이페이지')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('로그인이 필요합니다.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('로그인하러 가기'),
              ),
            ],
          ),
        ),
      );
    }

    final userAsync = ref.watch(myPageUserProvider(user.uid));
    final contractsAsync = ref.watch(myActiveContractsProvider(user.uid));
    final paymentsAsync = ref.watch(myPaymentsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사용자 정보 섹션
            userAsync.when(
              data: (userData) => userData == null 
                  ? const Text('사용자 정보를 찾을 수 없습니다.') 
                  : _UserInfoSection(user: userData),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('사용자 정보 로드 오류: $err'),
            ),
            const SizedBox(height: 24),

            // 활성 계약 섹션
            const Text('활성 계약 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            contractsAsync.when(
              data: (contracts) => contracts.isEmpty
                  ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('현재 활성 계약이 없습니다.')))
                  : Column(children: contracts.map((c) => _ContractCard(contract: c)).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('계약 정보 로드 오류: $err'),
            ),
            const SizedBox(height: 24),

            // 납부 내역 섹션
            const Text('납부 내역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            paymentsAsync.when(
              data: (payments) => payments.isEmpty
                  ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('납부 내역이 없습니다.')))
                  : Column(children: payments.map((p) => _PaymentListItem(payment: p)).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('납부 내역 로드 오류: $err'),
            ),
            
            const SizedBox(height: 40),
            // 로그아웃 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _confirmAndLogout(context, ref),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('로그아웃'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout(BuildContext context, WidgetRef ref) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('현재 계정에서 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}

class _UserInfoSection extends StatelessWidget {
  final UserModel user;
  const _UserInfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _InfoRow(label: '이름', value: user.name),
            _InfoRow(label: '전화번호', value: user.phone),
            _InfoRow(label: '이메일', value: user.loginEmail),
            _InfoRow(label: '계정 상태', value: user.status == 'active' ? '활성' : '비활성'),
            _InfoRow(label: '역할', value: user.role == 'admin' ? '관리자' : '일반 고객'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Contract contract;
  const _ContractCard({required this.contract});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('방 ID: ${contract.roomId}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            _InfoRow(label: '계약 시작일', value: contract.startDate),
            _InfoRow(label: '계약 종료일', value: contract.endDate),
            _InfoRow(label: '월 이용료', value: '${NumberFormat('#,###').format(contract.monthlyFee)}원'),
            _InfoRow(label: '정기 납부일', value: '매월 ${contract.paymentDueDate}일'),
          ],
        ),
      ),
    );
  }
}

class _PaymentListItem extends StatelessWidget {
  final Payment payment;
  const _PaymentListItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    String statusText = '미납';
    Color statusColor = Colors.orange;
    if (payment.status == 'paid') {
      statusText = '완료';
      statusColor = Colors.green;
    } else if (payment.status == 'overdue') {
      statusText = '연체';
      statusColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${payment.dueDate} 납부건'),
        subtitle: Text('금액: ${NumberFormat('#,###').format(payment.amount)}원'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(26),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
