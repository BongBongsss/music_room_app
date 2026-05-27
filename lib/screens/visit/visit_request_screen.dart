import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:music_room_app/models/visit.dart';
import 'package:music_room_app/services/visit_service.dart';
import 'package:music_room_app/services/settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VisitRequestScreen extends ConsumerStatefulWidget {
  final String roomId;
  const VisitRequestScreen({super.key, required this.roomId});

  @override
  ConsumerState<VisitRequestScreen> createState() => _VisitRequestScreenState();
}

class _VisitRequestScreenState extends ConsumerState<VisitRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _memoController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isSubmitting = false;
  StreamSubscription<Map<String, dynamic>>? _settingsSub;

  Map<String, dynamic> _settings = {
    'visitAvailableDays': [1, 2, 3, 4, 5],
    'visitStartTime': '09:00',
    'visitEndTime': '21:00',
  };

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_updateState);
    _nameController.addListener(_updateState);
    _subscribeSettings();
  }

  void _subscribeSettings() {
    _settingsSub = ref.read(settingsServiceProvider).watchVisitSettings().listen(
      (settings) {
        if (!mounted) return;
        setState(() {
          _settings = settings;
        });

        final slots = _generateTimeSlots();
        if (_selectedTime != null && !slots.contains(_selectedTime)) {
          setState(() {
            _selectedTime = null;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예약 설정을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.')),
        );
      },
    );
  }

  void _updateState() {
    setState(() {});
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _phoneController.removeListener(_updateState);
    _nameController.removeListener(_updateState);
    _nameController.dispose();
    _phoneController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '전화번호를 입력해주세요.';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final isValid = RegExp(r'^01[0-9]{8,9}$').hasMatch(digits);
    if (!isValid) return '올바른 전화번호 형식이 아닙니다. (예: 010-1234-5678)';
    return null;
  }

  bool get _isFormValid {
    return _nameController.text.isNotEmpty && 
           _validatePhone(_phoneController.text) == null &&
           _selectedDate != null &&
           _selectedTime != null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final availableDays = List<int>.from(_settings['visitAvailableDays'] ?? []);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _getNextAvailableDate(availableDays),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: (date) => availableDays.contains(date.weekday % 7),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
    }
  }

  DateTime _getNextAvailableDate(List<int> availableDays) {
    if (availableDays.isEmpty) return DateTime.now();
    DateTime date = DateTime.now().add(const Duration(days: 1));
    for (int i = 0; i < 30; i++) {
      if (availableDays.contains(date.weekday % 7)) return date;
      date = date.add(const Duration(days: 1));
    }
    return DateTime.now();
  }

  List<String> _generateTimeSlots() {
    final startStr = _settings['visitStartTime'] as String? ?? '09:00';
    final endStr = _settings['visitEndTime'] as String? ?? '21:00';
    final start = int.tryParse(startStr.split(':')[0]) ?? 9;
    final end = int.tryParse(endStr.split(':')[0]) ?? 21;
    
    if (end < start) return [];

    return List.generate(end - start + 1, (i) {
      final hour = start + i;
      return '${hour.toString().padLeft(2, '0')}:00';
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방문 날짜와 시간을 선택해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final visitService = ref.read(visitServiceProvider);
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final user = FirebaseAuth.instance.currentUser;
      final visit = Visit(
        visitId: '',
        userId: user?.uid ?? 'guest',
        userName: _nameController.text,
        userPhone: _phoneController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        roomId: widget.roomId,
        visitDate: formattedDate,
        visitTime: _selectedTime!,
        status: 'pending',
        memo: _memoController.text,
        createdAt: DateTime.now(),
      );

      await visitService.requestVisit(visit);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('신청 완료'),
            content: const Text('방문 예약 신청이 완료되었습니다.\n확인 후 연락드리겠습니다.'),
            actions: [
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = _generateTimeSlots();

    return Scaffold(
      appBar: AppBar(title: const Text('방문 예약 신청')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('방문 정보를 입력해주세요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '성함', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (value) => (value == null || value.isEmpty) ? '성함을 입력해주세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: '연락처', hintText: '010-0000-0000', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              const SizedBox(height: 24),
              const Text('방문 희망일', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today),
                label: Text(_selectedDate == null ? '날짜 선택' : DateFormat('yyyy년 MM월 dd일').format(_selectedDate!)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.centerLeft),
              ),
              const SizedBox(height: 24),
              const Text('방문 희망 시간', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              timeSlots.isEmpty
                  ? const Text('현재 예약 가능한 시간이 없습니다. 관리자 설정을 확인해주세요.', style: TextStyle(color: Colors.red))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: timeSlots.map((time) {
                        final isSelected = _selectedTime == time;
                        return ChoiceChip(
                          label: Text(time),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedTime = selected ? time : null);
                          },
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(labelText: '문의사항 (선택)', border: OutlineInputBorder(), alignLabelWithHint: true),
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: (_isSubmitting || !_isFormValid) ? null : _handleSubmit,
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('예약 신청하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
