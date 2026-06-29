import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/services/settings_service.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final List<int> _availableDays = [];
  String _weekdayStartTime = '09:00';
  String _weekdayEndTime = '21:00';
  String _weekendStartTime = '09:00';
  String _weekendEndTime = '21:00';
  final _kakaoController = TextEditingController();
  final _mapController = TextEditingController();
  bool _isLoading = false;

  final List<String> _dayNames = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _kakaoController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref.read(settingsServiceProvider).getVisitSettings();
      setState(() {
        _availableDays.clear();
        _availableDays.addAll(List<int>.from(settings['visitAvailableDays'] ?? []));
        _weekdayStartTime = settings['weekdayStartTime'] ?? '09:00';
        _weekdayEndTime = settings['weekdayEndTime'] ?? '21:00';
        _weekendStartTime = settings['weekendStartTime'] ?? '09:00';
        _weekendEndTime = settings['weekendEndTime'] ?? '21:00';
        _kakaoController.text = settings['kakaoOpenChatUrl'] ?? '';
        _mapController.text = settings['mapUrl'] ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(settingsServiceProvider).updateVisitSettings({
        'visitAvailableDays': _availableDays,
        'weekdayStartTime': _weekdayStartTime,
        'weekdayEndTime': _weekdayEndTime,
        'weekendStartTime': _weekendStartTime,
        'weekendEndTime': _weekendEndTime,
        'kakaoOpenChatUrl': _kakaoController.text.trim(),
        'mapUrl': _mapController.text.trim(),
        'updatedAt': DateTime.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('설정이 저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_availableDays.contains(day)) {
        _availableDays.remove(day);
      } else {
        _availableDays.add(day);
        _availableDays.sort();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('연습실 정보 설정'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveSettings,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('방문 예약 가능 요일', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final bool isSelected = _availableDays.contains(index);
                    return GestureDetector(
                      onTap: () => _toggleDay(index),
                      child: CircleAvatar(
                        backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
                        child: Text(
                          _dayNames[index],
                          style: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                const Text('평일 예약 가능 시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _weekdayStartTime,
                        decoration: const InputDecoration(labelText: '평일 시작'),
                        items: List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00')
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _weekdayStartTime = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('~'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _weekdayEndTime,
                        decoration: const InputDecoration(labelText: '평일 종료'),
                        items: List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00')
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _weekdayEndTime = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('주말 예약 가능 시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _weekendStartTime,
                        decoration: const InputDecoration(labelText: '주말 시작'),
                        items: List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00')
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _weekendStartTime = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('~'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _weekendEndTime,
                        decoration: const InputDecoration(labelText: '주말 종료'),
                        items: List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00')
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _weekendEndTime = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('문의 및 지도 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _kakaoController,
                  decoration: const InputDecoration(
                    labelText: '카카오톡 오픈채팅 링크',
                    hintText: 'https://open.kakao.com/...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.chat_bubble, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _mapController,
                  decoration: const InputDecoration(
                    labelText: '네이버/카카오 지도 링크',
                    hintText: 'https://naver.me/... 또는 https://kakaom.ap/...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 40),
                const Divider(),
                const Text(
                  '※ 이 설정은 앱 메뉴의 위치 안내 및 카카오톡 문의에 즉시 반영됩니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
    );
  }
}
