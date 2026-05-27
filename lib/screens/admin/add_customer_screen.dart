import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/firebase_options.dart';
import 'package:music_room_app/models/user_model.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/user_service.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);

      // 1. 이메일 변환 및 중복 확인
      final email = authService.formatPhoneToEmail(_phoneController.text.trim());
      final exists = await userService.isUserExists(email);
      if (exists) {
        throw Exception('이미 등록된 연락처입니다.');
      }

      // 2. 임시 비밀번호 (전화번호 뒷 4자리 + 1234 등)
      final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final tempPassword = '${phone.substring(phone.length - 4)}1234';

      // 3. 신규 계정 생성 (관리자 로그아웃 방지를 위해 보조 앱 사용)
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      UserCredential credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      final String uid = credential.user!.uid;

      // 4. Firestore 유저 문서 생성
      final newUser = UserModel(
        userId: uid,
        name: _nameController.text.trim(),
        phone: phone,
        loginEmail: email,
        role: 'customer',
        status: 'active',
        isFirstLogin: true,
        createdAt: DateTime.now(),
      );

      await userService.createUser(newUser);

      // 5. 보조 앱 종료
      await secondaryApp.delete();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('계정 생성 완료'),
            content: Text('성함: ${_nameController.text}\n아이디: $email\n임시비번: $tempPassword\n\n고객에게 정보를 전달해주세요.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 팝업 닫기
                  Navigator.pop(context); // 이전 화면으로
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('신규 계약자 등록')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '신규 고객 정보를 입력하면\n자동으로 앱 로그인 계정이 생성됩니다.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '고객 성함',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => (value == null || value.isEmpty) ? '성함을 입력해주세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '연락처',
                  hintText: '010-0000-0000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return '연락처를 입력해주세요.';
                  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(digits)) {
                    return '올바른 전화번호 형식이 아닙니다.';
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
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('계정 생성 및 등록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
