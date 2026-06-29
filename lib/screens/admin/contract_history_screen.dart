import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/contract.dart';
import 'package:music_room_app/services/contract_service.dart';
import 'package:music_room_app/services/user_service.dart';
import 'package:intl/intl.dart';

final contractHistoryProvider = StreamProvider.family<List<Contract>, String>((ref, roomId) {
  return ref.watch(contractServiceProvider).getContractHistoryByRoom(roomId);
});

class ContractHistoryScreen extends ConsumerWidget {
  final String roomId;
  const ContractHistoryScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(contractHistoryProvider(roomId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('계약 이력 조회'),
      ),
      body: historyAsync.when(
        data: (contracts) {
          if (contracts.isEmpty) {
            return const Center(child: Text('계약 이력이 없습니다.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              final contract = contracts[index];
              return FutureBuilder(
                future: ref.read(userServiceProvider).getUser(contract.userId),
                builder: (context, snapshot) {
                  final userName = snapshot.data?.name ?? '로딩중...';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('기간: ${contract.startDate} ~ ${contract.endDate}'),
                          Text('월세: ${NumberFormat('#,###').format(contract.monthlyFee)}원'),
                        ],
                      ),
                      trailing: _StatusChip(status: contract.status),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('오류 발생: $err')),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = Colors.blue;
        label = '계약중';
        break;
      case 'expired':
        color = Colors.grey;
        label = '만료';
        break;
      case 'terminated':
        color = Colors.red;
        label = '해지';
        break;
      default:
        color = Colors.black;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
