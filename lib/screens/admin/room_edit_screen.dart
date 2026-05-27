import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:music_room_app/services/storage_service.dart';

class RoomEditScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomEditScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomEditScreen> createState() => _RoomEditScreenState();
}

class _RoomEditScreenState extends ConsumerState<RoomEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sizeController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _floorController = TextEditingController();
  final _featureController = TextEditingController();

  List<String> _existingPhotos = [];
  final List<File> _newPhotos = [];
  List<String> _features = [];
  String _status = 'vacant';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    setState(() => _isLoading = true);
    final room = await ref.read(roomServiceProvider).getRoomById(widget.roomId);
    if (room != null) {
      _nameController.text = room.name;
      _sizeController.text = room.size.toString();
      _priceController.text = room.price.toString();
      _descriptionController.text = room.description;
      _floorController.text = room.floor;
      _existingPhotos = List.from(room.photos);
      _features = List.from(room.features);
      _status = room.status;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sizeController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _floorController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_existingPhotos.length + _newPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 최대 5장까지 등록 가능합니다.')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _newPhotos.add(File(pickedFile.path));
      });
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      _existingPhotos.removeAt(index);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
  }

  void _addFeature() {
    final text = _featureController.text.trim();
    if (text.isNotEmpty && !_features.contains(text)) {
      setState(() {
        _features.add(text);
        _featureController.clear();
      });
    }
  }

  void _removeFeature(String feature) {
    setState(() {
      _features.remove(feature);
    });
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final List<String> uploadedUrls = [];
      for (var file in _newPhotos) {
        final url = await ref.read(storageServiceProvider).uploadRoomPhoto(widget.roomId, file);
        uploadedUrls.add(url);
      }

      final room = await ref.read(roomServiceProvider).getRoomById(widget.roomId);

      final updatedRoom = Room(
        roomId: widget.roomId,
        name: _nameController.text,
        size: double.tryParse(_sizeController.text) ?? 0.0,
        sizeUnit: 'm^2',
        price: int.tryParse(_priceController.text) ?? 0,
        priceUnit: '원',
        description: _descriptionController.text,
        photos: [..._existingPhotos, ...uploadedUrls],
        features: _features,
        status: _status,
        floor: _floorController.text,
        adminMemo: room?.adminMemo,
        updatedAt: DateTime.now(),
        createdAt: room?.createdAt,
      );

      await ref.read(roomServiceProvider).updateRoom(updatedRoom);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('룸 정보가 성공적으로 수정되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _nameController.text.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('룸 정보 수정'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveRoom,
              child: const Text('저장', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '호실명', hintText: '예: A호실'),
                  validator: (value) => value == null || value.isEmpty ? '호실명을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sizeController,
                        decoration: const InputDecoration(labelText: '크기 (m^2)', hintText: '예: 10.5'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) => value == null || value.isEmpty ? '크기를 입력해주세요.' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _floorController,
                        decoration: const InputDecoration(labelText: '층', hintText: '예: B1'),
                        validator: (value) => value == null || value.isEmpty ? '층을 입력해주세요.' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: '월 이용료 (원)', hintText: '예: 300000'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty ? '이용료를 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '설명'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                const Text('특징 (태그)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ..._features.map((f) => Chip(
                          label: Text(f),
                          onDeleted: () => _removeFeature(f),
                        )),
                    ActionChip(
                      label: const Icon(Icons.add, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('특징 추가'),
                            content: TextField(
                              controller: _featureController,
                              decoration: const InputDecoration(hintText: '예: 방음 완비, 에어컨'),
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                              TextButton(
                                onPressed: () {
                                  _addFeature();
                                  Navigator.pop(context);
                                },
                                child: const Text('추가'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('상태', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'vacant', child: Text('공실')),
                        DropdownMenuItem(value: 'occupied', child: Text('계약중')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('사진 (최대 5장)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._existingPhotos.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Image.network(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                              Positioned(
                                right: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeExistingPhoto(entry.key),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      ..._newPhotos.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Image.file(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                              Positioned(
                                right: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeNewPhoto(entry.key),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (_existingPhotos.length + _newPhotos.length < 5)
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.add_a_photo),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
