import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/room_map_layout.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/contract_service.dart';
import 'package:music_room_app/services/notice_service.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:music_room_app/services/settings_service.dart';
import 'package:music_room_app/widgets/room_map_view.dart';
import 'package:url_launcher/url_launcher.dart';

final roomListProvider = StreamProvider<List<Room>>((ref) {
  return ref.watch(roomServiceProvider).getRooms();
});

final homeRoomMapLayoutProvider = StreamProvider<RoomMapLayout>((ref) {
  return ref.watch(settingsServiceProvider).watchRoomMapLayout();
});

enum _RoomHomeView { map, list }

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  int _selectedTab = 0;
  _RoomHomeView _roomView = _RoomHomeView.map;
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
        final userDoc =
            await ref.read(authServiceProvider).validateAndGetUser(user.uid);
        if (mounted) {
          setState(() => _userRole = userDoc.role);

          if (_userRole == 'customer') {
            final roomIds = await ref
                .read(contractServiceProvider)
                .getActiveRoomIdsByUser(user.uid);
            if (mounted) setState(() => _myRoomIds = roomIds);
          }
        }
      } catch (e) {
        debugPrint('Error initializing user data: $e');
      }
    }
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _onAccountPressed() async {
    context.push('/my-page');
  }

  Future<void> _openMapLink() async {
    final settings = await ref.read(settingsServiceProvider).getVisitSettings();
    final mapUrl = settings['mapUrl'] as String?;
    if (!mounted) return;
    await _openExternalLink(
      mapUrl,
      emptyMessage: '등록된 위치 정보가 없습니다.',
    );
  }

  Future<void> _openKakaoLink() async {
    final url = await ref.read(settingsServiceProvider).getKakaoOpenChatUrl();
    if (!mounted) return;
    await _openExternalLink(
      url,
      emptyMessage: '등록된 카카오톡 링크가 없습니다.',
    );
  }

  Future<void> _openExternalLink(
    String? url, {
    required String emptyMessage,
  }) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }

    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('링크를 열 수 없습니다.')),
    );
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      _openMapLink();
      return;
    }
    if (index == 3) {
      _openKakaoLink();
      return;
    }
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 132,
        leading: const Padding(
          padding: EdgeInsets.only(left: 14),
          child: _BrandTitle(),
        ),
        title: Text(_selectedTab == 0 ? '방목록' : '공지사항'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _onAccountPressed,
            icon: const Icon(Icons.person),
            tooltip: '마이페이지',
          ),
        ],
      ),
      body: _selectedTab == 0 ? _buildRoomsTab() : const _NoticeTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: const Color(0xFF8A94A3),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.meeting_room_outlined),
            activeIcon: _ActiveNavIcon(icon: Icons.meeting_room),
            label: '방목록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            activeIcon: _ActiveNavIcon(icon: Icons.notifications),
            label: '공지사항',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: _ActiveNavIcon(icon: Icons.map),
            label: '위치안내',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: _ActiveNavIcon(icon: Icons.chat_bubble),
            label: '카카오톡 문의',
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsTab() {
    final roomListAsync = ref.watch(roomListProvider);
    final layoutAsync = ref.watch(homeRoomMapLayoutProvider);

    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return roomListAsync.when(
      data: (rooms) => Column(
        children: [
          if (_userRole != null && _userRole != 'guest')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SegmentedButton<_RoomHomeView>(
                segments: const [
                  ButtonSegment(
                    value: _RoomHomeView.map,
                    icon: Icon(Icons.grid_view),
                    label: Text('안내도'),
                  ),
                  ButtonSegment(
                    value: _RoomHomeView.list,
                    icon: Icon(Icons.list),
                    label: Text('리스트'),
                  ),
                ],
                selected: {_roomView},
                onSelectionChanged: (selection) {
                  setState(() => _roomView = selection.first);
                },
              ),
            ),
          Expanded(
            child: _roomView == _RoomHomeView.map
                ? layoutAsync.when(
                    data: (layout) => VacantPulseScope(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEFEFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD8DEE4),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Column(
                              children: [
                                const _HomeStatusLegend(),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: _HomeMapViewport(
                                    layout: layout,
                                    rooms: rooms,
                                  ),
                                ),
                                _HomeFacilityLegend(layout: layout),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Center(child: Text('안내도를 불러오지 못했습니다.\n$error')),
                  )
                : _RoomListView(
                    rooms: rooms,
                    myRoomIds: _myRoomIds,
                    userRole: _userRole,
                  ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('오류 발생: $err')),
    );
  }
}

class _ActiveNavIcon extends StatelessWidget {
  final IconData icon;

  const _ActiveNavIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
      ),
      child: Icon(icon, size: 21, color: const Color(0xFF1E3A8A)),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.music_note,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MPR',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                height: 1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '음악연습실',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeStatusLegend extends StatelessWidget {
  const _HomeStatusLegend();

  @override
  Widget build(BuildContext context) {
    final pulse = VacantPulseScope.valueOf(context);
    final vacantColor = Color.lerp(
      const Color(0xFF287A4B),
      const Color(0xFF55A96F),
      pulse,
    )!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          _HomeLegendItem(color: vacantColor, label: '공실'),
          const _HomeLegendItem(
            color: Color(0xFFF1F5F9),
            label: '계약중',
          ),
        ],
      ),
    );
  }
}

class _HomeFacilityLegend extends StatelessWidget {
  final RoomMapLayout layout;

  const _HomeFacilityLegend({required this.layout});

  @override
  Widget build(BuildContext context) {
    final kinds = <RoomMapFacilityKind>[];
    for (final item in layout.items) {
      final kind = facilityKindForItem(item);
      if (kind != RoomMapFacilityKind.none && !kinds.contains(kind)) {
        kinds.add(kind);
      }
    }

    if (kinds.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: kinds.map((kind) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE3E8EF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FacilityMapIcon(kind: kind, size: 16),
                const SizedBox(width: 5),
                Text(
                  _facilityLabel(kind),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _facilityLabel(RoomMapFacilityKind kind) {
    return switch (kind) {
      RoomMapFacilityKind.none => '',
      RoomMapFacilityKind.toilet => '화장실',
      RoomMapFacilityKind.extinguisher => '소화기',
      RoomMapFacilityKind.waterPurifier => '정수기',
      RoomMapFacilityKind.microwave => '전자렌지',
      RoomMapFacilityKind.fridge => '냉장고',
      RoomMapFacilityKind.vacuum => '청소기',
    };
  }
}

class _HomeLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _HomeLegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x1A000000)),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMapViewport extends StatelessWidget {
  final RoomMapLayout layout;
  final List<Room> rooms;

  const _HomeMapViewport({
    required this.layout,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = layout.fitToWidth ? 24.0 : 0.0;
        final maxWidth = constraints.maxWidth - horizontalPadding;
        final scale = layout.fitToWidth && maxWidth > 0
            ? (maxWidth / layout.width).clamp(0.75, 1.8).toDouble()
            : 1.0;
        final scaledWidth = layout.width * scale;
        final scaledHeight = layout.height * scale;
        final viewportWidth = constraints.maxWidth > scaledWidth
            ? constraints.maxWidth
            : scaledWidth;
        final viewportHeight = scaledHeight.clamp(
          0.0,
          constraints.maxHeight,
        );

        return SizedBox(
          height: viewportHeight,
          child: InteractiveViewer(
            panEnabled: false,
            scaleEnabled: false,
            minScale: 0.75,
            maxScale: 3,
            boundaryMargin: EdgeInsets.zero,
            constrained: false,
            child: SizedBox(
              width: viewportWidth,
              height: viewportHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: scaledWidth,
                  height: scaledHeight,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: RoomMapView(layout: layout, rooms: rooms),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoomListView extends StatelessWidget {
  final List<Room> rooms;
  final Set<String> myRoomIds;
  final String? userRole;

  const _RoomListView({
    required this.rooms,
    required this.myRoomIds,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const Center(child: Text('등록된 방이 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return RoomCard(
          room: room,
          isMyRoom: myRoomIds.contains(room.roomId),
          userRole: userRole,
        );
      },
    );
  }
}

class _NoticeTab extends ConsumerWidget {
  const _NoticeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticeListAsync = ref.watch(noticesProvider);

    return noticeListAsync.when(
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
                  fontWeight:
                      notice.isPinned ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                notice.createdAt != null
                    ? DateFormat('yyyy.MM.dd').format(notice.createdAt!)
                    : '',
              ),
              onTap: () =>
                  context.push('/notices/${notice.noticeId}', extra: notice),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('오류 발생: $err')),
    );
  }
}

class RoomCard extends StatelessWidget {
  final Room room;
  final bool isMyRoom;
  final String? userRole;

  const RoomCard({
    super.key,
    required this.room,
    this.isMyRoom = false,
    this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/rooms/${room.roomId}'),
        child: Padding(
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isMyRoom)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '내 방',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  StatusBadge(status: room.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '크기: ${room.dimensions} | 층수: ${room.floor}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
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
