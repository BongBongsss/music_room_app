import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/services/room_service.dart';

class RoomAddScreen extends ConsumerStatefulWidget {
  const RoomAddScreen({super.key});

  @override
  ConsumerState<RoomAddScreen> createState() => _RoomAddScreenState();
}

class _RoomAddScreenState extends ConsumerState<RoomAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _floorController = TextEditingController(text: '1');
  final _widthController = TextEditingController(); // 가로
  final _heightController = TextEditingController(); // 세로
  final _priceController = TextEditingController();
  final _depositController = TextEditingController(); 
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _floorController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';
      final newRoom = Room(
        roomId: roomId,
        name: _nameController.text.trim(),
        floor: _floorController.text.trim(),
        dimensions: '${_widthController.text.trim()} x ${_heightController.text.trim()}',
        price: int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0,
        priceUnit: '원',
        deposit: int.tryParse(_depositController.text.replaceAll(',', '')) ?? 0,
        description: _descriptionController.text.trim(),
        photos: [], 
        features: [],
        status: 'vacant', 
        createdAt: DateTime.now(),
      );

      await ref.read(roomServiceProvider).addRoom(newRoom);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새로운 룸이 등록되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('신규 룸 등록')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '룸 이름 (예: A호실)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.door_sliding),
                    ),
                    validator: (val) => (val == null || val.isEmpty) ? '이름을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _floorController,
                          decoration: const InputDecoration(
                            labelText: '층수 (예: B1)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => (val == null || val.isEmpty) ? '필수' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _widthController,
                          decoration: const InputDecoration(
                            labelText: '가로 (m)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => (val == null || val.isEmpty) ? '필수' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          decoration: const InputDecoration(
                            labelText: '세로 (m)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => (val == null || val.isEmpty) ? '필수' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: '월세 (원)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) => (val == null || val.isEmpty) ? '금액을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _depositController,
                    decoration: const InputDecoration(
                      labelText: '보증금 (원)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) => (val == null || val.isEmpty) ? '보증금을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: '룸 상세 설명',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('등록하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
