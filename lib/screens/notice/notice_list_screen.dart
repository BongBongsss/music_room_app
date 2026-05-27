import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:music_room_app/services/notice_service.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> {
  Future<void> _onAccountPressed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await ref.read(authServiceProvider).validateAndGetUser(user.uid);
      final bool isAdmin = userDoc.role == 'admin';
      if (!mounted) return;
      await _showAccountMenu(isAdmin: isAdmin);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정 정보를 확인하지 못했습니다.')),
      );
      await _showAccountMenu(isAdmin: false);
    }
  }

  Future<void> _showAccountMenu({required bool isAdmin}) async {
    await showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('관리자 대시보드'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  context.go('/admin');
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _confirmAndLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    if (!mounted) return;
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('현재 로그인되어 있습니다. 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authServiceProvider).signOut();
    }
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
