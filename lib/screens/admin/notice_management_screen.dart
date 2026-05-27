import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/notice.dart';
import 'package:music_room_app/services/notice_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class NoticeManagementScreen extends ConsumerWidget {
  const NoticeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticeListAsync = ref.watch(noticesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('공지사항 관리')),
      body: noticeListAsync.when(
        data: (notices) {
          if (notices.isEmpty) {
            return const Center(child: Text('등록된 공지사항이 없습니다.'));
          }
          return ListView.builder(
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final notice = notices[index];
              return ListTile(
                leading: IconButton(
                  icon: Icon(
                    notice.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: notice.isPinned ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => ref.read(noticeServiceProvider).togglePin(notice),
                ),
                title: Text(notice.title),
                subtitle: Text(
                  notice.createdAt != null
                      ? DateFormat('yyyy.MM.dd').format(notice.createdAt!)
                      : '',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, ref, notice),
                ),
                onTap: () => context.push('/admin/notice-edit', extra: notice),
              );
            },
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Firestore 연결 중...'),
              Text('연결이 안 되면 인터넷이나 프로젝트 설정을 확인해주세요.'),
            ],
          ),
        ),
        error: (err, stack) {
          debugPrint('Error: $err');
          return Center(child: Text('에러 발생: $err'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/notice-edit'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Notice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: const Text('삭제한 공지는 복구할 수 없습니다. 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(noticeServiceProvider).deleteNotice(notice.noticeId);
    }
  }
}
