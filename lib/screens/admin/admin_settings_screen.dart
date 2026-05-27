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
  String _startTime = '09:00';
  String _endTime = '21:00';
  bool _isLoading = false;

  final List<String> _dayNames = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref.read(settingsServiceProvider).getVisitSettings();
      setState(() {
        _availableDays.clear();
        _availableDays.addAll(List<int>.from(settings['visitAvailableDays'] ?? []));
        _startTime = settings['visitStartTime'] ?? '09:00';
        _endTime = settings['visitEndTime'] ?? '21:00';
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
    final startHour = int.tryParse(_startTime.split(':')[0]) ?? 9;
    final endHour = int.tryParse(_endTime.split(':')[0]) ?? 21;
    
    if (startHour > endHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 시간은 종료 시간보다 늦을 수 없습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(settingsServiceProvider).updateVisitSettings({
        'visitAvailableDays': _availableDays,
        'visitStartTime': _startTime,
        'visitEndTime': _endTime,
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
                const Text('방문 예약 가능 시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _startTime,
                        decoration: const InputDecoration(labelText: '시작 시간'),
                        items: List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00')
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _startTime = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('~'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _endTime,
                        decoration: const InputDecoration(labelText: '종료 시간'),
                        items: List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00')
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _endTime = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Divider(),
                const Text(
                  '※ 이 설정은 고객의 방문 예약 신청 화면에 즉시 반영됩니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
    );
  }
}
