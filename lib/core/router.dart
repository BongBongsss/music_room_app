import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/screens/auth/login_screen.dart';
import 'package:music_room_app/screens/auth/change_password_screen.dart';
import 'package:music_room_app/screens/rooms/room_list_screen.dart';
import 'package:music_room_app/screens/rooms/room_detail_screen.dart';
import 'package:music_room_app/screens/visit/visit_request_screen.dart';
import 'package:music_room_app/screens/admin/admin_dashboard_screen.dart';
import 'package:music_room_app/screens/admin/add_customer_screen.dart';
import 'package:music_room_app/screens/admin/room_edit_screen.dart';
import 'package:music_room_app/screens/admin/room_memo_screen.dart';
import 'package:music_room_app/screens/admin/contract_history_screen.dart';
import 'package:music_room_app/screens/admin/payment_management_screen.dart';
import 'package:music_room_app/screens/admin/notice_management_screen.dart';
import 'package:music_room_app/screens/admin/notice_edit_screen.dart';
import 'package:music_room_app/screens/admin/admin_settings_screen.dart';
import 'package:music_room_app/screens/notice/notice_list_screen.dart';
import 'package:music_room_app/screens/home/notice_detail_screen.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:music_room_app/models/notice.dart';

class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: RouterRefreshStream(authService.authStateChanges),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const RoomListScreen()),
      GoRoute(
        path: '/rooms/:id',
        builder: (context, state) => RoomDetailScreen(roomId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'visit',
            builder: (context, state) => VisitRequestScreen(roomId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/notices', builder: (context, state) => const NoticeListScreen()),
      GoRoute(
        path: '/notices/:id',
        builder: (context, state) => NoticeDetailScreen(notice: state.extra as Notice),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(path: 'add-customer', builder: (context, state) => const AddCustomerScreen()),
          GoRoute(path: 'room-edit/:id', builder: (context, state) => RoomEditScreen(roomId: state.pathParameters['id']!)),
          GoRoute(path: 'room-memo/:id', builder: (context, state) => RoomMemoScreen(roomId: state.pathParameters['id']!)),
          GoRoute(path: 'contract-history/:id', builder: (context, state) => ContractHistoryScreen(roomId: state.pathParameters['id']!)),
          GoRoute(path: 'payment-management', builder: (context, state) => const PaymentManagementScreen()),
          GoRoute(path: 'notice-management', builder: (context, state) => const NoticeManagementScreen()),
          GoRoute(path: 'notice-edit', builder: (context, state) => NoticeEditScreen(notice: state.extra as Notice?)),
          GoRoute(path: 'settings', builder: (context, state) => const AdminSettingsScreen()),
        ],
      ),
    ],
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.matchedLocation;
      debugPrint('[Router] Redirecting to: $location, user: ${user != null}');

      // 1. 비로그인 상태
      if (user == null) {
        final isPublic =
            location == '/login' ||
            location == '/notices' ||
            location.startsWith('/notices/') ||
            location.startsWith('/rooms/');

        if (!isPublic) {
          debugPrint('[Router][Reason] User is null and path is protected. Redirecting to /login');
          return '/login';
        }

        // 비로그인 상태에서 홈(/) 접근도 로그인으로 보냄
        if (location == '/') {
          debugPrint('[Router][Reason] User is null on home. Redirecting to /login');
          return '/login';
        }

        debugPrint('[Router][Reason] User is null but path is public. Proceeding to $location');
        return null;
      }

      // 2. 로그인 상태
      try {
        final userDoc = await ref.read(authServiceProvider).validateAndGetUser(user.uid);
        debugPrint('[Router][Reason] User role: ${userDoc.role}, isFirstLogin: ${userDoc.isFirstLogin}');
        
        // 비밀번호 변경 필요시
        if (userDoc.isFirstLogin && location != '/change-password') {
          debugPrint('[Router][Reason] Forced redirect to /change-password');
          return '/change-password';
        }

        // Admin 접근 제어
        if (location.startsWith('/admin')) {
          if (userDoc.role != 'admin') {
            debugPrint('[Router][Reason] Access denied to /admin for non-admin user. Redirecting to /');
            return '/';
          }
          debugPrint('[Router][Reason] Admin access granted.');
          return null;
        }

        // 로그인한 관리자가 홈에 있으면 관리자 페이지로 이동
        if (location == '/' && userDoc.role == 'admin') {
          debugPrint('[Router][Reason] Admin user on home page. Redirecting to /admin');
          return '/admin';
        }
        
        debugPrint('[Router][Reason] Logged in user proceeding to $location');
        return null;
      } catch (e) {
        debugPrint('[Router][Reason] Exception caught: $e. Redirecting to /login');
        return '/login';
      }
    },
  );
});
