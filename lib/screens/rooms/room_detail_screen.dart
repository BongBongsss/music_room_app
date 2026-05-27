import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:go_router/go_router.dart';

final roomDetailProvider = FutureProvider.family<Room?, String>((ref, roomId) {
  return ref.watch(roomServiceProvider).getRoomById(roomId);
});

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomDetailProvider(roomId));

    return Scaffold(
      appBar: AppBar(title: const Text('룸 상세 정보')),
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return const Center(child: Text('해당 룸 정보를 찾을 수 없습니다.'));
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 사진 섹션
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
                          child: const Icon(Icons.image, size: 100, color: Colors.grey),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            room.name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          _StatusBadge(status: room.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(icon: Icons.square_foot, label: '크기', value: '${room.size}${room.sizeUnit}'),
                      _InfoRow(icon: Icons.layers, label: '층수', value: room.floor),
                      _InfoRow(
                        icon: Icons.payments,
                        label: '월 대여료',
                        value: '${room.price}${room.priceUnit}',
                        valueColor: Colors.blue,
                      ),
                      const Divider(height: 32),
                      const Text(
                        '룸 설명',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room.description,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '주요 특징',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: room.status == 'vacant' 
                          ? () => context.push('/rooms/${room.roomId}/visit')
                          : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: Text(
                          room.status == 'vacant' ? '방문 예약 신청하기' : '현재 이용 중인 룸입니다',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류 발생: $err')),
      ),
    );
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
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
