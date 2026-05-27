import 'package:flutter/material.dart';

class AuthGateErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onLogin;
  final Object? error;

  const AuthGateErrorScreen({
    super.key,
    required this.onRetry,
    required this.onLogin,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                '인증 정보를 확인하는 중 오류가 발생했습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? '알 수 없는 오류가 발생했습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('다시 시도'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onLogin,
                  child: const Text('로그인 화면으로 이동'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
