import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/services/log_service.dart';
import 'package:intl/intl.dart';

final logListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(logServiceProvider).getLogs();
});

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(logListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 활동 로그'),
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('기록된 활동 로그가 없습니다.'));
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final timestamp = log['timestamp'] as dynamic;
              String timeStr = '시간 정보 없음';
              
              if (timestamp != null) {
                final date = (timestamp as dynamic).toDate();
                timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
              }

              return ListTile(
                leading: _buildActionIcon(log['action']),
                title: Text('${log['userName']} (${log['userRole']})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${log['action']} - ${log['details'] ?? ""}'),
                    Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('오류 발생: $err')),
      ),
    );
  }

  Widget _buildActionIcon(String action) {
    IconData iconData;
    Color color;

    switch (action) {
      case '로그인':
        iconData = Icons.login;
        color = Colors.blue;
        break;
      case '예약신청':
        iconData = Icons.event;
        color = Colors.green;
        break;
      case '방 수정':
        iconData = Icons.edit;
        color = Colors.orange;
        break;
      default:
        iconData = Icons.info_outline;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(iconData, color: color, size: 20),
    );
  }
}
