import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/contract.dart';
import 'package:music_room_app/models/visit.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/user_service.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:music_room_app/services/visit_service.dart';
import 'package:music_room_app/services/contract_service.dart';
import 'package:music_room_app/screens/admin/statistics_tab.dart';
import 'package:intl/intl.dart';

final roomListProvider = StreamProvider<List<Room>>((ref) {
  return ref.watch(roomServiceProvider).getRooms();
});

final allVisitsProvider = StreamProvider<List<Visit>>((ref) {
  return ref.watch(visitServiceProvider).getAllVisits();
});

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
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
                  Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                  SizedBox(height: 8),
                  Text(
                    '운영자 관리 모드',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
          _PaymentTabPlaceholder(),
          StatisticsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 3) {
            context.push('/admin/payment-management');
          } else {
            setState(() => _selectedIndex = index);
          }
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

class _PaymentTabPlaceholder extends StatelessWidget {
  const _PaymentTabPlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _RoomStatusTab extends ConsumerWidget {
  const _RoomStatusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomListAsync = ref.watch(roomListProvider);
    final activeContractsAsync = ref.watch(activeContractsProvider);

    return roomListAsync.when(
      data: (rooms) {
        return activeContractsAsync.when(
          data: (contracts) {
            final vacantCount = rooms.where((r) => r.status == 'vacant').length;
            final occupiedCount = rooms.where((r) => r.status == 'occupied').length;
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
                ),
                Expanded(
                  child: rooms.isEmpty 
                    ? const Center(child: Text('등록된 룸이 없습니다.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          final matchedContract = contracts.cast<Contract?>().firstWhere(
                            (c) => c?.roomId == room.roomId,
                            orElse: () => null,
                          );
                          return _AdminRoomCard(room: room, contract: matchedContract);
                        },
                      ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('계약 정보 오류: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('룸 정보 오류: $err')),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int total, vacant, occupied, impending;
  const _SummaryHeader({
    required this.total, 
    required this.vacant, 
    required this.occupied,
    required this.impending,
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
              _SummaryItem(label: '전체', value: total.toString(), color: Colors.black),
              _SummaryItem(label: '공실', value: vacant.toString(), color: Colors.green),
              _SummaryItem(label: '계약중', value: occupied.toString(), color: Colors.blue),
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
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
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
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _AdminRoomCard extends StatelessWidget {
  final Room room;
  final dynamic contract;
  const _AdminRoomCard({required this.room, this.contract});

  @override
  Widget build(BuildContext context) {
    final bool isVacant = room.status == 'vacant';
    Widget? impendingBadge;
    if (contract != null) {
      final endDate = DateTime.tryParse(contract.endDate);
      if (endDate != null) {
        final diff = endDate.difference(DateTime.now()).inDays;
        if (diff <= 7) {
          impendingBadge = _Badge(text: '만료임박', color: Colors.red);
        } else if (diff <= 30) {
          impendingBadge = _Badge(text: '만료임박', color: Colors.orange);
        }
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (room.adminMemo != null && room.adminMemo!.isNotEmpty)
                  const Icon(Icons.sticky_note_2, size: 18, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 4),
            if (impendingBadge != null) impendingBadge,
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isVacant ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isVacant ? '공실' : '계약중',
                style: TextStyle(color: isVacant ? Colors.green : Colors.blue, fontSize: 12),
              ),
            ),
            if (!isVacant && contract != null) ...[
              const SizedBox(height: 4),
              Text(
                '납부일: 매월 ${contract.paymentDueDate}일',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${NumberFormat('#,###').format(room.price)}원',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                      onPressed: () => context.push('/admin/room-edit/${room.roomId}'),
                      tooltip: '정보 수정',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.note_alt_outlined, size: 18, color: Colors.orange),
                      onPressed: () => context.push('/admin/room-memo/${room.roomId}'),
                      tooltip: '내부 메모',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.history, size: 18, color: Colors.grey),
                      onPressed: () => context.push('/admin/contract-history/${room.roomId}'),
                      tooltip: '계약 이력',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _VisitManagementTab extends ConsumerStatefulWidget {
  const _VisitManagementTab();

  @override
  ConsumerState<_VisitManagementTab> createState() => _VisitManagementTabState();
}

class _VisitManagementTabState extends ConsumerState<_VisitManagementTab> {
  final Map<String, bool> _loadingStates = {};
  String _selectedVisitFilter = 'pending';

  Future<void> _handleUpdateStatus(String visitId, String status, String message) async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(displayError)));
      }
    } finally {
      debugPrint('[VisitManagement] Update status finally: setting loading to false');
      if (mounted) {
        setState(() => _loadingStates[visitId] = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getEmptyMessage() {
    switch (_selectedVisitFilter) {
      case 'pending': return '대기중인 방문 예약이 없습니다.';
      case 'confirmed': return '확정된 방문 예약이 없습니다.';
      case 'cancelled': return '취소된 방문 예약이 없습니다.';
      default: return '방문 예약 내역이 없습니다.';
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
                  : visits.where((v) => v.status == _selectedVisitFilter).toList();

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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              _statusBadge(visit.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('방문일시: ${visit.visitDate} ${visit.visitTime}'),
                          if (visit.memo != null && visit.memo!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('메모: ${visit.memo}', style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                    onPressed: visit.visitId.isEmpty ? null : () => _handleUpdateStatus(visit.visitId, 'cancelled', '방문 예약이 취소됐습니다.'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('취소'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: visit.visitId.isEmpty ? null : () => _handleUpdateStatus(visit.visitId, 'confirmed', '방문 예약이 확정됐습니다.'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    child: const Text('확정'),
                                  ),
                                ]
                              ],
                            )
                          ],
                          if (visit.visitId.isEmpty) 
                            const Text('(ID 오류 - 처리 불가)', style: TextStyle(color: Colors.red, fontSize: 11)),
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
      case 'confirmed': label = '확정'; break;
      case 'cancelled': label = '취소'; break;
      case 'pending': label = '대기'; break;
      default: label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _UserManagementTab extends ConsumerWidget {
  const _UserManagementTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(StreamProvider((ref) => ref.watch(userServiceProvider).getAllCustomers()));

    return Scaffold(
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) return const Center(child: Text('등록된 계약자가 없습니다.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final user = customers[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user.name),
                  subtitle: Text(user.phone),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.status == 'active' ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.status == 'active' ? '이용중' : '비활성',
                      style: TextStyle(color: user.status == 'active' ? Colors.green : Colors.red, fontSize: 12),
                    ),
                  ),
                  onTap: () {},
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('오류: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/add-customer'),
        label: const Text('신규 등록'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
