import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/firebase_options.dart';
import 'package:music_room_app/models/user_model.dart';
import 'package:music_room_app/models/contract.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/user_service.dart';
import 'package:music_room_app/screens/admin/admin_dashboard_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '010');
  final _monthlyFeeController = TextEditingController();
  final _depositController = TextEditingController();
  final _dueDateController = TextEditingController(text: '1');
  final _instrumentController = TextEditingController(); // 악기 정보 컨트롤러 추가

  String _contractType = 'fixed'; // 'fixed' or 'monthly'
  String? _selectedRoomId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _monthlyFeeController.dispose();
    _depositController.dispose();
    _dueDateController.dispose();
    _instrumentController.dispose(); // 해제
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 365));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _handleCreateCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('계약할 룸을 선택해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    FirebaseApp? secondaryApp;

    try {
      final authService = ref.read(authServiceProvider);
      final firestore = FirebaseFirestore.instance;

      final email =
          authService.formatPhoneToEmail(_phoneController.text.trim());

      final userExists =
          await ref.read(userServiceProvider).isUserExists(email);
      if (userExists) throw Exception('이미 등록된 연락처입니다.');

      final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final tempPassword = '${phone.substring(phone.length - 4)}1234';

      final appName = 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}';

      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      String? uid;
      try {
        UserCredential credential =
            await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
        uid = credential.user!.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          if (!mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('기존 계정 발견'),
              content: const Text('이미 가입된 계정입니다. 기존 계정을 활성화하고 계약을 진행하시겠습니까?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('활성화')),
              ],
            ),
          );

          if (confirmed == true) {
            final userQuery = await firestore
                .collection('users')
                .where('loginEmail', isEqualTo: email)
                .get();
            if (userQuery.docs.isNotEmpty) {
              uid = userQuery.docs.first.id;
            } else {
              throw Exception('기존 유저 정보를 찾을 수 없습니다.');
            }
          } else {
            throw Exception('등록이 취소되었습니다.');
          }
        } else {
          rethrow;
        }
      }

      final batch = firestore.batch();
      final contractRef = firestore.collection('contracts').doc();
      final contractId = contractRef.id;
      final deposit =
          int.parse(_depositController.text.replaceAll(',', ''));

      final newUser = UserModel(
        userId: uid,
        name: _nameController.text.trim(),
        phone: phone,
        loginEmail: email,
        role: 'customer',
        status: 'active',
        contractId: contractId,
        isFirstLogin: true,
        createdAt: DateTime.now(),
      );
      batch.set(firestore.collection('users').doc(uid), newUser.toMap());

      final newContract = Contract(
        contractId: contractId,
        userId: uid,
        roomId: _selectedRoomId!,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: _contractType == 'fixed'
            ? DateFormat('yyyy-MM-dd').format(_endDate)
            : '',
        monthlyFee: int.parse(_monthlyFeeController.text.replaceAll(',', '')),
        paymentDueDate: int.parse(_dueDateController.text),
        paymentMethod: '계좌이체',
        status: 'active',
        contractType: _contractType,
        renewalDay: _contractType == 'monthly' ? _dueDateController.text : null,
        instrument: _instrumentController.text.trim(), // 악기 정보 저장
        createdAt: DateTime.now(),
      );
      batch.set(contractRef, newContract.toMap());

      batch.update(firestore.collection('rooms').doc(_selectedRoomId), {
        'status': 'occupied',
        'deposit': deposit,
      });

      await batch.commit();

      if (mounted) {
        // 1. 정보를 미리 캡처 (setState 전에 저장)
        final roomList = ref.read(roomListProvider).value ?? [];
        final room = roomList.firstWhere((r) => r.roomId == _selectedRoomId,
            orElse: () => Room(
                roomId: 'unknown',
                name: '알 수 없음',
                dimensions: '0 x 0',
                price: 0,
                priceUnit: '원',
                deposit: 0,
                description: '',
                photos: [],
                features: [],
                status: 'vacant',
                floor: ''));

        final String roomName = room.name;
        final String savedName = _nameController.text;
        final String savedEmail = email;
        final String savedTempPass = tempPassword;

        // 2. 즉시 상태 초기화 (UI rebuild 에러 방지)
        setState(() {
          _nameController.clear();
          _phoneController.text = '010';
          _monthlyFeeController.clear();
          _depositController.clear();
          _selectedRoomId = null;
        });

        // 3. 다이얼로그 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('등록 및 계약 완료'),
            content: Text(
                '성함: $savedName\n아이디: $savedEmail\n임시비번: $savedTempPass\n룸: $roomName\n\n고객에게 정보를 전달해주세요.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }

      try {
        await secondaryApp.delete();
      } catch (e) {
        debugPrint('[AddCustomer] Error deleting secondary app: $e');
      }
    } catch (e) {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류 발생: $errorMsg')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomListAsync = ref.watch(roomListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('신규 계약자 등록')),
      body: roomListAsync.when(
        data: (rooms) {
          final vacantRooms = rooms.where((r) => r.status == 'vacant').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle(title: '기본 정보'),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: '고객 성함',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder()),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? '성함을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                        labelText: '연락처',
                        hintText: '010-0000-0000',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '연락처를 입력해주세요.';
                      }
                      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(digits)) {
                        return '올바른 전화번호 형식이 아닙니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle(title: '계약 정보'),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedRoomId),
                    initialValue:
                        vacantRooms.any((r) => r.roomId == _selectedRoomId)
                            ? _selectedRoomId
                            : null,
                    decoration: const InputDecoration(
                        labelText: '계약 룸 선택',
                        prefixIcon: Icon(Icons.door_sliding),
                        border: OutlineInputBorder()),
                    items: vacantRooms
                        .map((r) => DropdownMenuItem(
                            value: r.roomId, child: Text(r.name)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedRoomId = val;
                        if (val != null) {
                          final room =
                              vacantRooms.firstWhere((r) => r.roomId == val);
                          _monthlyFeeController.text = room.price.toString();
                          _depositController.text = room.deposit.toString();
                        }
                      });
                    },
                    validator: (value) => value == null ? '룸을 선택해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                          value: 'fixed',
                          label: Text('기간 지정'),
                          icon: Icon(Icons.calendar_month)),
                      ButtonSegment<String>(
                          value: 'monthly',
                          label: Text('매월 갱신'),
                          icon: Icon(Icons.refresh)),
                    ],
                    selected: {_contractType},
                    onSelectionChanged: (newSelection) =>
                        setState(() => _contractType = newSelection.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instrumentController,
                    decoration: const InputDecoration(
                        labelText: '사용 악기',
                        hintText: '예: 피아노, 드럼',
                        prefixIcon: Icon(Icons.music_note),
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  // 계약 시작일은 항상 선택 가능하게 변경
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(context, true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                        '계약 시작일: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                  ),
                  const SizedBox(height: 16),
                  if (_contractType == 'fixed') ...[
                    OutlinedButton.icon(
                      onPressed: () => _selectDate(context, false),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                          '계약 종료일: ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
                    ),
                  ] else ...[
                    TextFormField(
                      initialValue: '자동 갱신 (종료일 없음)',
                      readOnly: true,
                      decoration: const InputDecoration(
                          labelText: '계약 유형',
                          prefixIcon: Icon(Icons.info),
                          border: OutlineInputBorder()),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _monthlyFeeController,
                          decoration: const InputDecoration(
                              labelText: '월세 (원)',
                              prefixIcon: Icon(Icons.payments),
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) => (value == null || value.isEmpty)
                              ? '금액을 입력해주세요.'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _dueDateController,
                          decoration: const InputDecoration(
                              labelText: '납부일 (일)',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '필수';
                            }
                            final day = int.tryParse(value);
                            if (day == null || day < 1 || day > 31) {
                              return '1~31';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _depositController,
                    decoration: const InputDecoration(
                        labelText: '보증금 (원)',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '보증금을 입력해주세요.';
                      }
                      final deposit = int.tryParse(value.replaceAll(',', ''));
                      if (deposit == null || deposit < 0) {
                        return '올바른 보증금을 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreateCustomer,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('계정 생성 및 계약 완료',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('데이터 로딩 오류: $err')),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey)),
    );
  }
}
