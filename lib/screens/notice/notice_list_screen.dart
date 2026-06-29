import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/services/notice_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> {
  Future<void> _onAccountPressed() async {
    context.push('/my-page');
  }

  @override
  Widget build(BuildContext context) {
    final noticeListAsync = ref.watch(noticesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        actions: [
          IconButton(
            onPressed: _onAccountPressed,
            icon: const Icon(Icons.person),
            tooltip: '마이페이지',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, color: Colors.white, size: 48),
                  SizedBox(height: 8),
                  Text(
                    '음악연습실',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room),
              title: const Text('룸 목록'),
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('공지사항'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('위치 안내'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('카카오톡 문의'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
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
                leading: notice.isPinned
                    ? const Icon(Icons.push_pin, color: Colors.red)
                    : const Icon(Icons.notifications_none),
                title: Text(
                  notice.title,
                  style: TextStyle(
                    fontWeight: notice.isPinned ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  notice.createdAt != null
                      ? DateFormat('yyyy.MM.dd').format(notice.createdAt!)
                      : '',
                ),
                onTap: () => context.push('/notices/${notice.noticeId}', extra: notice),
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
