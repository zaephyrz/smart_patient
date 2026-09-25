import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/reset_password_screen.dart';
import 'features/auth/screens/pin_setup_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/appointments/screens/book_appointment_screen.dart';
import 'features/medical_records/screens/records_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/notifications/screens/notification_screen.dart';

class SmartPatientApp extends ConsumerStatefulWidget {
  const SmartPatientApp({super.key});

  @override
  ConsumerState<SmartPatientApp> createState() => _SmartPatientAppState();
}

class _SmartPatientAppState extends ConsumerState<SmartPatientApp> {
  @override
  void initState() {
    super.initState();
    _handleInitialRoute();
  }

  void _handleInitialRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      final token = uri.queryParameters['token'];
      final email = uri.queryParameters['email'];

      if (token != null && email != null && token.isNotEmpty && email.isNotEmpty) {
        _navigateToResetPassword(token, email);
      }
    });
  }

  void _navigateToResetPassword(String token, String email) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              token: token,
              email: email,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      home: _buildHomeScreen(authState),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/pin-setup': (context) => const PinSetupScreen(isFirstTime: true),
        '/dashboard': (context) => const DashboardScreen(),
        '/book-appointment': (context) => const BookAppointmentScreen(),
        '/records': (context) => const MedicalRecordsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/notifications': (context) => const NotificationScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/video-call') {
          // Handled via VCallHelper browser integration
          return null;
        }
        
        if (settings.name?.startsWith('/reset-password') == true) {
          final uri = Uri.parse(settings.name!);
          final token = uri.queryParameters['token'];
          final email = uri.queryParameters['email'];
          
          if (token != null && email != null && token.isNotEmpty && email.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(
                token: token,
                email: email,
              ),
            );
          }
        }
        
        return null;
      },
    );
  }

  Widget _buildHomeScreen(AuthState authState) {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final email = uri.queryParameters['email'];
    
    if (token != null && email != null && token.isNotEmpty && email.isNotEmpty) {
      return ResetPasswordScreen(
        token: token,
        email: email,
      );
    }

    if (authState.isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryBlue,
          ),
        ),
      );
    }

    if (authState.isAuthenticated) {
      return Consumer(
        builder: (context, ref, _) {
          final hasPin = ref.watch(hasPinProvider);
          
          // If user has a PIN, show PIN verification screen
          if (hasPin) {
            return PinSetupScreen(
              isFirstTime: false, // This triggers verify mode
              email: authState.email,
            );
          }
          
          // If no PIN, go to dashboard
          return const DashboardScreen();
        },
      );
    }

    return const LoginScreen();
  }
}