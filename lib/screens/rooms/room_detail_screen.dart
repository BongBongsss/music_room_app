import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/contract_service.dart';
import 'package:music_room_app/services/log_service.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:music_room_app/services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

final roomDetailProvider = FutureProvider.family<Room?, String>((ref, roomId) {
  return ref.watch(roomServiceProvider).getRoomById(roomId);
});

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;

  const RoomDetailScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomDetailProvider(roomId));

    roomAsync.whenData((room) {
      if (room == null) return;

      Future.microtask(() async {
        final user = FirebaseAuth.instance.currentUser;
        var userName = '익명유저';
        var userRole = 'guest';

        if (user != null) {
          try {
            final userModel = await ref
                .read(authServiceProvider)
                .validateAndGetUser(user.uid);
            userName = userModel.name;
            userRole = userModel.role;
          } catch (_) {}
        }

        ref.read(logServiceProvider).addLog(
              action: '방조회',
              userName: userName,
              userRole: userRole,
              details: '${room.name} 상세 정보 확인',
            );
      });
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로가기',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/');
          },
        ),
        title: const Text('룸 상세 정보'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: '홈',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return const Center(child: Text('해당 룸 정보를 찾을 수 없습니다.'));
          }

          return FutureBuilder<bool>(
            future: _canSeeExactPrice(ref, room.roomId),
            builder: (context, snapshot) {
              final canSeeExactPrice = snapshot.data ?? false;
              final priceValue = _buildPriceText(room, canSeeExactPrice);
              final depositValue = _buildDepositText(room, canSeeExactPrice);

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: room.status == 'vacant'
                                  ? () async {
                                      final uri = Uri(
                                        scheme: Uri.base.scheme,
                                        host: Uri.base.host,
                                        port: Uri.base.hasPort
                                            ? Uri.base.port
                                            : null,
                                        path: '/visit_request.html',
                                        queryParameters: {
                                          'roomId': room.roomId,
                                        },
                                      );
                                      await launchUrl(
                                        uri,
                                        webOnlyWindowName: '_self',
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: Text(
                                room.status == 'vacant'
                                    ? '방문 예약 신청하기'
                                    : '현재 이용 중',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openKakaoInquiry(context, ref),
                              icon: const Icon(Icons.chat_bubble, size: 18),
                              label: const Text(
                                '카카오톡 문의하기',
                                textAlign: TextAlign.center,
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                backgroundColor: const Color(0xFFFEE500),
                                foregroundColor: const Color(0xFF191919),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
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
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _StatusBadge(status: room.status),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                              icon: Icons.square_foot,
                              label: '크기',
                              value: room.dimensions),
                          _InfoRow(
                              icon: Icons.layers,
                              label: '층수',
                              value: room.floor),
                          _InfoRow(
                            icon: Icons.payments,
                            label: '월 이용료',
                            value: priceValue,
                            valueColor: Colors.blue,
                          ),
                          _InfoRow(
                            icon: Icons.security,
                            label: '보증금',
                            value: depositValue,
                            valueColor: Colors.orange,
                          ),
                          if (!canSeeExactPrice) ...[
                            const SizedBox(height: 12),
                            const Center(
                              child: Text(
                                '상세 가격은 카톡 문의해주세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF287A4B),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          const Text(
                            '주요 특징',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: room.features.map((feature) {
                              return Chip(
                                label: Text(feature),
                                backgroundColor: Colors.blue[50],
                                side: BorderSide.none,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 250,
                      child: room.photos.isNotEmpty
                          ? PageView.builder(
                              itemCount: room.photos.length,
                              itemBuilder: (context, index) {
                                return Image.network(
                                  room.photos[index],
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image,
                                size: 100,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류 발생: $err')),
      ),
    );
  }

  String _buildPriceText(Room room, bool canSeeExactPrice) {
    if (canSeeExactPrice) {
      return '${NumberFormat('#,###').format(room.price)}${room.priceUnit}';
    }

    return '문의';
  }

  String _buildDepositText(Room room, bool canSeeExactPrice) {
    if (canSeeExactPrice) {
      return '${NumberFormat('#,###').format(room.deposit)}원';
    }

    return '있음';
  }

  Future<void> _openKakaoInquiry(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final url = await ref.read(settingsServiceProvider).getKakaoOpenChatUrl();
    if (!context.mounted) return;

    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 카카오톡 링크가 없습니다.')),
      );
      return;
    }

    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카카오톡 링크를 열 수 없습니다.')),
    );
  }

  Future<bool> _canSeeExactPrice(WidgetRef ref, String roomId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userDoc =
          await ref.read(authServiceProvider).validateAndGetUser(user.uid);
      if (userDoc.role == 'admin') return true;

      if (userDoc.role == 'customer') {
        final myRoomIds = await ref
            .read(contractServiceProvider)
            .getActiveRoomIdsByUser(user.uid);
        return myRoomIds.contains(roomId);
      }
    } catch (_) {}

    return false;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isVacant = status == 'vacant';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isVacant ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isVacant ? '공실 (예약 가능)' : '계약중',
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
