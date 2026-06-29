import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/room_map_layout.dart';
import 'package:music_room_app/models/user_model.dart';
import 'package:music_room_app/models/contract.dart';
import 'package:music_room_app/models/visit.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/user_service.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:music_room_app/services/settings_service.dart';
import 'package:music_room_app/services/visit_service.dart';
import 'package:music_room_app/services/contract_service.dart';
import 'package:music_room_app/screens/admin/statistics_tab.dart';
import 'package:music_room_app/screens/admin/payment_management_screen.dart';
import 'package:music_room_app/widgets/room_map_view.dart';

final roomListProvider = StreamProvider<List<Room>>((ref) {
  return ref.watch(roomServiceProvider).getRooms();
});

final allVisitsProvider = StreamProvider<List<Visit>>((ref) {
  return ref.watch(visitServiceProvider).getAllVisits();
});

final allCustomersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(userServiceProvider).getAllCustomers();
});

final adminRoomMapLayoutProvider = StreamProvider<RoomMapLayout>((ref) {
  return ref.watch(settingsServiceProvider).watchRoomMapLayout();
});

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운영자 대시보드'),
        actions: [
          IconButton(
            onPressed: () async {
              debugPrint('[AdminDashboard] 로그아웃 버튼 클릭됨');
              await ref.read(authServiceProvider).signOut();
              if (!context.mounted) return;
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings,
                      color: Colors.white, size: 48),
                  SizedBox(height: 8),
                  Text(
                    '운영자 관리 모드',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const Text('대시보드 홈'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('공지사항 관리'),
              onTap: () {
                Navigator.pop(context);
                context.push('/admin/notice-management');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('연습실 정보 설정'),
              onTap: () {
                Navigator.pop(context);
                context.push('/admin/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('연습실 도면 편집'),
              onTap: () {
                Navigator.pop(context);
                context.push('/admin/room-map-editor');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('사용자 활동 로그'),
              onTap: () {
                Navigator.pop(context);
                context.push('/admin/activity-log');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (!context.mounted) return;
                context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _RoomStatusTab(),
          _VisitManagementTab(),
          _UserManagementTab(),
          PaymentManagementScreen(showAppBar: false),
          StatisticsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: '룸 현황'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note), label: '방문 예약'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: '계약자 관리'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: '납부 관리'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '통계'),
        ],
      ),
    );
  }
}

class _RoomStatusTab extends ConsumerStatefulWidget {
  const _RoomStatusTab();

  @override
  ConsumerState<_RoomStatusTab> createState() => _RoomStatusTabState();
}

class _RoomStatusTabState extends ConsumerState<_RoomStatusTab> {
  String _roomFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final roomListAsync = ref.watch(roomListProvider);
    final activeContractsAsync = ref.watch(activeContractsProvider);
    final customersAsync = ref.watch(allCustomersProvider);
    final layoutAsync = ref.watch(adminRoomMapLayoutProvider);

    return Scaffold(
      body: roomListAsync.when(
        data: (rooms) {
          return activeContractsAsync.when(
            data: (contracts) {
              return customersAsync.when(
                data: (customers) {
                  final vacantCount =
                      rooms.where((r) => r.status == 'vacant').length;
                  final occupiedCount =
                      rooms.where((r) => r.status == 'occupied').length;
                  int impendingCount = 0;
                  final now = DateTime.now();
                  for (var contract in contracts) {
                    final endDate = DateTime.tryParse(contract.endDate);
                    if (endDate != null) {
                      final diff = endDate.difference(now).inDays;
                      if (diff <= 30) impendingCount++;
                    }
                  }

                  return Column(
                    children: [
                      _SummaryHeader(
                        total: rooms.length,
                        vacant: vacantCount,
                        occupied: occupiedCount,
                        impending: impendingCount,
                        selectedFilter: _roomFilter,
                        onFilterChanged: (filter) =>
                            setState(() => _roomFilter = filter),
                      ),
                      Expanded(
                        child: rooms.isEmpty
                            ? const Center(child: Text('등록된 룸이 없습니다.'))
                            : layoutAsync.when(
                                data: (layout) => _AdminRoomMapViewport(
                                  layout: layout,
                                  rooms: rooms,
                                  contracts: contracts,
                                  customers: customers,
                                  filter: _roomFilter,
                                ),
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (err, _) =>
                                    Center(child: Text('도면 정보 오류: $err')),
                              ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('고객 목록 오류: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('계약 정보 오류: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('룸 정보 오류: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/room-add'),
        heroTag: null,
        tooltip: '신규 룸 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AdminRoomMapViewport extends StatelessWidget {
  final RoomMapLayout layout;
  final List<Room> rooms;
  final List<Contract> contracts;
  final List<UserModel> customers;
  final String filter;

  const _AdminRoomMapViewport({
    required this.layout,
    required this.rooms,
    required this.contracts,
    required this.customers,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final contractsByRoomId = {
      for (final contract in contracts) contract.roomId: contract,
    };
    final customersByUserId = {
      for (final customer in customers) customer.userId: customer,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthScale = constraints.maxWidth > 0
            ? (constraints.maxWidth - 12) / layout.width
            : 1.0;
        final heightScale = constraints.maxHeight > 0
            ? (constraints.maxHeight - 36) / layout.height
            : 1.0;
        final fitScale = widthScale < heightScale ? widthScale : heightScale;
        final scale = fitScale.clamp(0.55, 1.8).toDouble();
        final scaledWidth = layout.width * scale;
        final scaledHeight = layout.height * scale;

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 36),
            child: SizedBox(
              width: scaledWidth,
              height: scaledHeight,
              child: FittedBox(
                fit: BoxFit.fill,
                child: RoomMapView(
                  layout: layout,
                  rooms: rooms,
                  showTitle: false,
                  itemYOffset: -42,
                  roomContentBuilder: (context, item, room) {
                    final contract =
                        room == null ? null : contractsByRoomId[room.roomId];
                    final customer = contract == null
                        ? null
                        : customersByUserId[contract.userId];
                    return _AdminRoomMapTile(
                      label: item.label,
                      room: room,
                      contract: contract,
                      customer: customer,
                      filter: filter,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdminRoomMapTile extends StatelessWidget {
  final String label;
  final Room? room;
  final Contract? contract;
  final UserModel? customer;
  final String filter;

  const _AdminRoomMapTile({
    required this.label,
    required this.room,
    required this.contract,
    required this.customer,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final isVacant = room?.status == 'vacant';
    final isOccupied = room?.status == 'occupied';
    final shouldDim = switch (filter) {
      'vacant' => !isVacant,
      'occupied' => !isOccupied,
      _ => false,
    };

    final title = _roomNumberLabel(room, label);
    final details = isVacant || contract == null
        ? [
            if (room?.dimensions.trim().isNotEmpty == true)
              room!.dimensions.trim(),
          ]
        : [
            customer?.name.isNotEmpty == true ? customer!.name : '알 수 없음',
            '월 ${_formatManwon(contract!.monthlyFee)}',
            '보증금 ${_formatManwon(room?.deposit ?? 0)}',
          ];

    return Opacity(
      opacity: shouldDim ? 0.28 : 1,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                height: 1.05,
              ),
            ),
            const SizedBox(height: 2),
            ...details.map(
              (text) => Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isVacant ? 11 : 10,
                  fontWeight: FontWeight.w800,
                  color: isVacant
                      ? const Color(0xFF287A4B)
                      : const Color(0xFF31529B),
                  height: 1.08,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatManwon(int value) {
    final manwon = value / 10000;
    if (manwon == manwon.roundToDouble()) {
      return '${manwon.toInt()}만';
    }
    return '${manwon.toStringAsFixed(1)}만';
  }

  static String _roomNumberLabel(Room? room, String fallback) {
    final roomName = room?.name.trim();
    if (roomName != null && roomName.isNotEmpty) {
      final nameMatch =
          RegExp(r'(^|\D)(\d{1,2})(번|호|호실|$)').firstMatch(roomName);
      if (nameMatch != null) return nameMatch.group(2)!;
    }

    final roomId = room?.roomId.trim();
    if (roomId != null && roomId.isNotEmpty) {
      final idMatch = RegExp(r'(\d+)$').firstMatch(roomId);
      if (idMatch != null) {
        final number = int.tryParse(idMatch.group(1)!);
        if (number != null) return number.toString();
      }
    }

    final fallbackMatch =
        RegExp(r'(^|\D)(\d{1,2})(번|호|호실|$)').firstMatch(fallback);
    return fallbackMatch?.group(2) ?? fallback;
  }
}

class _SummaryHeader extends StatelessWidget {
  final int total, vacant, occupied, impending;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  const _SummaryHeader({
    required this.total,
    required this.vacant,
    required this.occupied,
    required this.impending,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                label: '전체',
                value: total.toString(),
                color: Colors.black,
                isSelected: selectedFilter == 'all',
                onTap: () => onFilterChanged('all'),
              ),
              _SummaryItem(
                label: '공실',
                value: vacant.toString(),
                color: Colors.green,
                isSelected: selectedFilter == 'vacant',
                onTap: () => onFilterChanged('vacant'),
              ),
              _SummaryItem(
                label: '계약중',
                value: occupied.toString(),
                color: Colors.blue,
                isSelected: selectedFilter == 'occupied',
                onTap: () => onFilterChanged('occupied'),
              ),
            ],
          ),
          if (impending > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '만료 임박 계약: $impending건',
                style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.35))
              : null,
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _VisitManagementTab extends ConsumerStatefulWidget {
  const _VisitManagementTab();

  @override
  ConsumerState<_VisitManagementTab> createState() =>
      _VisitManagementTabState();
}

class _VisitManagementTabState extends ConsumerState<_VisitManagementTab> {
  final Map<String, bool> _loadingStates = {};
  String _selectedVisitFilter = 'pending';

  Future<void> _handleUpdateStatus(
      String visitId, String status, String message) async {
    if (visitId.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예약 ID가 비어 있어 처리할 수 없습니다.')),
        );
      }
      return;
    }

    debugPrint('[VisitManagement] Update status clicked: $visitId -> $status');
    setState(() => _loadingStates[visitId] = true);

    try {
      await ref.read(visitServiceProvider).updateVisitStatus(visitId, status);
      debugPrint('[VisitManagement] Update status success: $visitId');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      debugPrint('[VisitManagement] Update status error: $e');
      if (mounted) {
        String displayError = '오류 발생: $e';
        if (e.toString().contains('권한이 없어')) {
          displayError = e.toString().replaceAll('Exception: ', '');
        } else if (e.toString().contains('네트워크')) {
          displayError = '네트워크 상태를 확인하고 다시 시도해주세요.';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(displayError)));
      }
    } finally {
      debugPrint(
          '[VisitManagement] Update status finally: setting loading to false');
      if (mounted) {
        setState(() => _loadingStates[visitId] = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getEmptyMessage() {
    switch (_selectedVisitFilter) {
      case 'pending':
        return '대기중인 방문 예약이 없습니다.';
      case 'confirmed':
        return '확정된 방문 예약이 없습니다.';
      case 'cancelled':
        return '취소된 방문 예약이 없습니다.';
      default:
        return '방문 예약 내역이 없습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(allVisitsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              _filterChip('대기', 'pending'),
              _filterChip('확정', 'confirmed'),
              _filterChip('취소', 'cancelled'),
              _filterChip('전체', 'all'),
            ],
          ),
        ),
        Expanded(
          child: visitsAsync.when(
            data: (visits) {
              final filteredVisits = _selectedVisitFilter == 'all'
                  ? visits
                  : visits
                      .where((v) => v.status == _selectedVisitFilter)
                      .toList();

              if (filteredVisits.isEmpty) {
                return Center(child: Text(_getEmptyMessage()));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredVisits.length,
                itemBuilder: (context, index) {
                  final visit = filteredVisits[index];
                  final isLoading = _loadingStates[visit.visitId] ?? false;
                  final isPending = visit.status == 'pending';

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
                                '${visit.userName} (${visit.userPhone})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              _statusBadge(visit.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('방문일시: ${visit.visitDate} ${visit.visitTime}'),
                          if (visit.memo != null && visit.memo!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('메모: ${visit.memo}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                          if (isPending) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isLoading)
                                  const CircularProgressIndicator()
                                else ...[
                                  OutlinedButton(
                                    onPressed: visit.visitId.isEmpty
                                        ? null
                                        : () => _handleUpdateStatus(
                                            visit.visitId,
                                            'cancelled',
                                            '방문 예약이 취소됐습니다.'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: const Text('취소'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: visit.visitId.isEmpty
                                        ? null
                                        : () => _handleUpdateStatus(
                                            visit.visitId,
                                            'confirmed',
                                            '방문 예약이 확정됐습니다.'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white),
                                    child: const Text('확정'),
                                  ),
                                ]
                              ],
                            )
                          ],
                          if (visit.visitId.isEmpty)
                            const Text('(ID 오류 - 처리 불가)',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('방문 예약을 불러오는 중...'),
                ],
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('방문 예약 데이터를 불러오지 못했습니다.'),
                    const SizedBox(height: 8),
                    Text('$err', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedVisitFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedVisitFilter = value);
      },
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[800] : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _statusBadge(String status) {
    String label;
    switch (status) {
      case 'confirmed':
        label = '확정';
        break;
      case 'cancelled':
        label = '취소';
        break;
      case 'pending':
        label = '대기';
        break;
      default:
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: _getStatusColor(status).withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: _getStatusColor(status),
            fontSize: 12,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _UserManagementTab extends ConsumerWidget {
  const _UserManagementTab();

  Future<void> _handleDeleteUser(BuildContext context, WidgetRef ref,
      UserModel user, Contract? activeContract) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 영구 삭제'),
        content: Text(
          '${user.name}님의 정보를 DB에서 삭제합니다.\n\n'
          '⚠️ 주의: Firebase Auth(로그인 계정)는 앱에서 직접 삭제가 불가능합니다. '
          'Firebase Console에서 해당 이메일 계정을 수동으로 삭제해야 완전히 정리됩니다.\n\n'
          '계속하시겠습니까?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('영구 삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(userServiceProvider).deleteUser(
            user.userId, activeContract?.contractId, activeContract?.roomId);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('데이터가 삭제되었습니다.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('삭제 오류: $e')));
        }
      }
    }
  }

  Future<void> _handleTerminate(BuildContext context, WidgetRef ref,
      UserModel user, Contract contract) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계약 해지'),
        content: Text('${user.name}님의 계약을 즉시 해지하시겠습니까?\n해당 룸은 즉시 공실 상태가 됩니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('해지 처리'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(contractServiceProvider).terminateContract(
              contractId: contract.contractId,
              userId: user.userId,
              roomId: contract.roomId,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('계약이 해지되었습니다.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('오류 발생: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(allCustomersProvider);
    final activeContractsAsync = ref.watch(activeContractsProvider);

    return Stack(
      children: [
        customersAsync.when(
          data: (customers) {
            if (customers.isEmpty) {
              return const Center(child: Text('등록된 계약자가 없습니다.'));
            }

            return activeContractsAsync.when(
              data: (contracts) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final user = customers[index];
                    final activeContract =
                        contracts.cast<Contract?>().firstWhere(
                              (c) => c?.userId == user.userId,
                              orElse: () => null,
                            );

                    return Card(
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.grey, size: 20),
                              onPressed: () => _handleDeleteUser(
                                  context, ref, user, activeContract),
                              tooltip: '데이터 영구 삭제',
                            ),
                            const CircleAvatar(child: Icon(Icons.person)),
                          ],
                        ),
                        title: Text(
                          user.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: user.status == 'active'
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          user.phone,
                          style: TextStyle(
                            color: user.status == 'active'
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (activeContract != null)
                              IconButton(
                                icon: const Icon(Icons.no_accounts,
                                    color: Colors.red, size: 20),
                                onPressed: () => _handleTerminate(
                                    context, ref, user, activeContract),
                                tooltip: '계약 해지',
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: user.status == 'active'
                                    ? Colors.green[50]
                                    : Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                user.status == 'active' ? '이용중' : '비활성',
                                style: TextStyle(
                                    color: user.status == 'active'
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => context
                            .push('/admin/customer-detail/${user.userId}'),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('계약 정보 오류: $err')),
            );
          },
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('계약자 목록을 불러오는 중...'),
              ],
            ),
          ),
          error: (err, stack) {
            debugPrint('[UserManagementTab] Error loading customers: $err');
            debugPrint(stack.toString());
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      '데이터를 불러오지 못했습니다.',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(allCustomersProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/add-customer'),
            heroTag: 'fab_user_mgmt',
            label: const Text('신규 등록'),
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
