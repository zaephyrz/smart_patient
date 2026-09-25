import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/pin_setup_screen.dart';
import '../core/services/storage_service.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Splash / Session Check Route on app startup
      GoRoute(
        path: '/',
        builder: (context, state) => const AppStartupScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/pin-verify',
        builder: (context, state) => const PinSetupScreen(isFirstTime: false),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final args = state.extra as Map<String, String>?;
          final token = args?['token'] ?? state.uri.queryParameters['token'] ?? '';
          final email = args?['email'] ?? state.uri.queryParameters['email'] ?? '';
          return ResetPasswordScreen(token: token, email: email);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
  
  static Future<void> handleDeepLink(BuildContext context, String link) async {
    final uri = Uri.parse(link);
    if (uri.path.contains('reset-password')) {
      final token = uri.queryParameters['token'] ?? '';
      final email = uri.queryParameters['email'] ?? '';
      if (token.isNotEmpty) {
        GoRouter.of(context).push('/reset-password', extra: {
          'token': token,
          'email': email,
        });
      }
    }
  }
}

/// Helper screen evaluated on cold app startup to determine persistent session state
class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final storage = StorageService();
    final token = await storage.getAuthToken();
    final userId = await storage.getUserId();
    final email = await storage.getUserEmail();
    final pin = await storage.getUserPin();

    if (!mounted) return;

    // If user is authenticated
    if (token != null && token.isNotEmpty && userId != null && email != null) {
      if (pin != null && pin.isNotEmpty) {
        // User has a PIN enabled -> send to PIN verification screen
        context.go('/pin-verify');
      } else {
        // No PIN -> go straight to dashboard
        context.go('/dashboard');
      }
    } else {
      // Not authenticated -> send to login
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}