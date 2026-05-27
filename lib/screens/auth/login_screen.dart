import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    debugPrint('[LoginScreen] 로그인 버튼 클릭됨: ${_emailController.text}');
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signIn(
            _emailController.text,
            _passwordController.text,
          );
      debugPrint('[LoginScreen] signIn 성공');
      
      if (mounted) {
        debugPrint('[LoginScreen] context.go("/") 호출 직전');
        context.go('/');
        debugPrint('[LoginScreen] context.go("/") 호출 직후');
      }
    } catch (e) {
      debugPrint('[LoginScreen] catch 진입: $e');
      if (mounted) {
        String errorMessage = '로그인 실패';
        if (e is FirebaseAuthException) {
          errorMessage = '로그인 오류: ${e.code} - ${e.message}';
        } else if (e is Exception) {
          errorMessage = '아이디 또는 비밀번호가 틀렸습니다.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final url = await ref.read(settingsServiceProvider).getKakaoOpenChatUrl();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('비밀번호 찾기 안내'),
        content: const Text(
          '비밀번호를 잊으셨나요? 카카오톡 오픈채팅으로 문의해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
          ElevatedButton.icon(
            onPressed: url == null || url.isEmpty
                ? null
                : () async {
                    Navigator.pop(dialogContext);

                    final String formattedUrl =
                        url.startsWith('http') ? url : 'https://$url';
                    final uri = Uri.parse(formattedUrl);

                    try {
                      if (await canLaunchUrl(uri)) {
                        if (!mounted) return;
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        throw Exception('링크를 열 수 없습니다.');
                      }
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('문의 링크를 여는 데 실패했습니다. 관리자에게 문의해주세요.'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.chat_bubble),
            label: const Text('오픈채팅으로 문의'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFE812),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('음악연습실 로그인', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '아이디 (이메일)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('로그인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text('비밀번호를 잊으셨나요?', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
