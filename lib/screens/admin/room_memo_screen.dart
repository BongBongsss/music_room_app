import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/services/room_service.dart';

class RoomMemoScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomMemoScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomMemoScreen> createState() => _RoomMemoScreenState();
}

class _RoomMemoScreenState extends ConsumerState<RoomMemoScreen> {
  final _memoController = TextEditingController();
  bool _isLoading = false;
  Room? _room;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    setState(() => _isLoading = true);
    final room = await ref.read(roomServiceProvider).getRoomById(widget.roomId);
    if (room != null) {
      _room = room;
      _memoController.text = room.adminMemo ?? '';
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _saveMemo() async {
    if (_room == null) return;

    setState(() => _isLoading = true);
    try {
      final updatedRoom = Room(
        roomId: _room!.roomId,
        name: _room!.name,
        dimensions: _room!.dimensions,
        price: _room!.price,
        priceUnit: _room!.priceUnit,
        deposit: _room!.deposit, // 보증금 필드 추가
        description: _room!.description,
        photos: _room!.photos,
        features: _room!.features,
        status: _room!.status,
        floor: _room!.floor,
        adminMemo: _memoController.text.trim(),
        createdAt: _room!.createdAt,
        updatedAt: DateTime.now(),
      );

      await ref.read(roomServiceProvider).updateRoom(updatedRoom);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('메모 저장 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_room?.name ?? "룸"} 내부 메모'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveMemo,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _isLoading && _room == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '운영자 전용 메모 (고객에게 노출되지 않음)',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _memoController,
                      decoration: const InputDecoration(
                        hintText: '룸에 대한 내부 전달사항이나 관리 기록을 입력하세요.',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
