import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:music_room_app/services/contract_service.dart';
import 'package:intl/intl.dart';

final roomListProvider = StreamProvider<List<Room>>((ref) {
  return ref.watch(roomServiceProvider).getRooms();
});

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  bool _showAllRooms = false;
  String? _userRole;
  Set<String> _myRoomIds = {};
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  Future<void> _initUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await ref.read(authServiceProvider).validateAndGetUser(user.uid);
        if (mounted) {
          setState(() {
            _userRole = userDoc.role;
          });

          if (_userRole == 'customer') {
            final roomIds = await ref.read(contractServiceProvider).getActiveRoomIdsByUser(user.uid);
            if (mounted) {
              setState(() {
                _myRoomIds = roomIds;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error initializing user data: $e');
      }
    }
    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

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
    await showModalBottomSheet<void>(
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
                  _goAdmin();
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

  void _goAdmin() {
    if (!mounted) return;
    context.go('/admin');
  }

  @override
  Widget build(BuildContext context) {
    final roomListAsync = ref.watch(roomListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('연습실 방 목록'),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room),
              title: const Text('방 목록'),
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('공지사항'),
              onTap: () {
                Navigator.pop(context);
                context.push('/notices');
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('위치 안내'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('카카오톡 문의'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _isInitializing 
        ? const Center(child: CircularProgressIndicator())
        : roomListAsync.when(
          data: (rooms) {
            List<Room> filteredRooms = rooms;
            
            if (_userRole == 'customer' && !_showAllRooms) {
              filteredRooms = rooms.where((r) => _myRoomIds.contains(r.roomId)).toList();
            }

            return Column(
              children: [
                if (_userRole == 'customer')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _showAllRooms ? '전체 방 보기' : '내 방만 보기',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _showAllRooms,
                          onChanged: (val) => setState(() => _showAllRooms = val),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: filteredRooms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _userRole == 'customer' && !_showAllRooms
                                ? '현재 배정된 내 방이 없습니다.\n관리자에게 문의해주세요.'
                                : '등록된 방이 없습니다.',
                              textAlign: TextAlign.center,
                            ),
                            if (!(_userRole == 'customer' && !_showAllRooms)) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  await ref.read(roomServiceProvider).seedSampleRooms();
                                },
                                child: const Text('샘플 데이터 생성하기'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRooms.length,
                        itemBuilder: (context, index) {
                          final room = filteredRooms[index];
                          final isMyRoom = _myRoomIds.contains(room.roomId);
                          return RoomCard(room: room, isMyRoom: isMyRoom);
                        },
                      ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('오류 발생: $err')),
        ),
    );
  }
}

class RoomCard extends StatelessWidget {
  final Room room;
  final bool isMyRoom;
  const RoomCard({super.key, required this.room, this.isMyRoom = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/rooms/${room.roomId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              color: Colors.grey[300],
              child: room.photos.isNotEmpty
                  ? Image.network(room.photos.first, fit: BoxFit.cover)
                  : const Icon(Icons.meeting_room, size: 80, color: Colors.grey),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isMyRoom)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '내 방',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      StatusBadge(status: room.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '크기: ${room.size}${room.sizeUnit} | 층수: ${room.floor}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${NumberFormat('#,###').format(room.price)}${room.priceUnit} / 월',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isVacant = status == 'vacant';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVacant ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isVacant ? '공실' : '계약중',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
