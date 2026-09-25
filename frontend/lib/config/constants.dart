import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color accentBlue = Color(0xFF1565C0);
  static const Color accentGreen = Color(0xFF2E7D32);
  
  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray900 = Color(0xFF212121);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
}

class AppConstants {
  // API Configuration
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = '/api';
  static const int requestTimeout = 30000; // 30 seconds
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String profileEndpoint = '/user/profile';
  static const String setupPinEndpoint = '/user/setup-pin';
  static const String appointmentsEndpoint = '/appointments';
  static const String medicalRecordsEndpoint = '/medical-records';
  
  // App Settings
  static const String appName = 'Smart Patient';
  static const String appVersion = '1.0.0';
  
  // Storage keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userProfileKey = 'user_profile';
  static const String userPinKey = 'user_pin';
  
  // Validation
  static const int minPasswordLength = 8;
  static const int pinLength = 4;
  static const int maxPinAttempts = 3;
  
  // Telemedicine
  static const String jitsiServer = 'meet.jit.si';
  static const String jitsiRoomPrefix = 'smart-medical-';
  
  // Additional endpoints
  static const String forgotPasswordEndpoint = '/auth/forgot-password';
  static const String resetPasswordEndpoint = '/auth/reset-password';
  static const String verifyEmailEndpoint = '/auth/verify-email';
  static const String resendVerificationEndpoint = '/auth/resend-verification';
  static const String updateProfileEndpoint = '/user/update-profile';
  static const String changePasswordEndpoint = '/user/change-password';
  static const String notificationsEndpoint = '/notifications';
  static const String prescriptionsEndpoint = '/prescriptions';
  static const String labResultsEndpoint = '/lab-results';
  static const String doctorsEndpoint = '/doctors';
  static const String hospitalsEndpoint = '/hospitals';
  static const String specialtiesEndpoint = '/specialties';
  static const String uploadDocumentEndpoint = '/upload/document';
}