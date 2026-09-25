import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

// State class for authentication
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool hasPin;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? error;
  final String? role;

  const AuthState({
    required this.isAuthenticated,
    this.isLoading = false,
    this.hasPin = false,
    this.userId,
    this.email,
    this.displayName,
    this.error,
    this.role,
  });

  factory AuthState.initial() {
    return const AuthState(
      isAuthenticated: false,
      isLoading: false,
      hasPin: false,
    );
  }

  factory AuthState.loading() {
    return const AuthState(
      isAuthenticated: false,
      isLoading: true,
      hasPin: false,
    );
  }

  factory AuthState.authenticated({
    required String userId,
    required String email,
    String? displayName,
    bool hasPin = false,
    String? role,
  }) {
    return AuthState(
      isAuthenticated: true,
      isLoading: false,
      hasPin: hasPin,
      userId: userId,
      email: email,
      displayName: displayName,
      role: role,
    );
  }

  factory AuthState.error(String error) {
    return AuthState(
      isAuthenticated: false,
      isLoading: false,
      hasPin: false,
      error: error,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? hasPin,
    String? userId,
    String? email,
    String? displayName,
    String? error,
    String? role,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      hasPin: hasPin ?? this.hasPin,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      error: error ?? this.error,
      role: role ?? this.role,
    );
  }
}

// =============================================
// AUTH PROVIDERS
// =============================================

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

// =============================================
// READ-ONLY PROVIDERS
// =============================================

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

final userEmailProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).email;
});

final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).userId;
});

final userDisplayNameProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).displayName;
});

final userDisplayNameWithFallbackProvider = Provider<String>((ref) {
  return ref.watch(authStateProvider).displayName ?? 'Patient';
});

final hasPinProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).hasPin;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).error;
});

final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).role;
});

final isDoctorProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).role == 'doctor';
});

// =============================================
// AUTH NOTIFIER
// =============================================

class AuthNotifier extends Notifier<AuthState> {
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();

  @override
  AuthState build() {
    _checkAuthStatus();
    return AuthState.initial();
  }

  Future<void> _checkAuthStatus() async {
    state = AuthState.loading();

    try {
      final token = await _storage.getAuthToken();
      final userId = await _storage.getUserId();
      final email = await _storage.getUserEmail();
      final userPin = await _storage.getUserPin();
      final role = await _storage.getUserRole();

      if (token != null && userId != null && email != null) {
        state = AuthState.authenticated(
          userId: userId,
          email: email,
          displayName: await _storage.getUserDisplayName(),
          hasPin: userPin != null,
          role: role,
        );
        
        await _verifyToken(token);
      } else {
        state = AuthState.initial();
      }
    } catch (e) {
      state = AuthState.error('Failed to check auth status: ${e.toString()}');
    }
  }

  Future<void> _verifyToken(String token) async {
    try {
      // Optional token verification - keep silent if it fails
    } catch (e) {
      await logout();
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();

    try {
      final result = await _api.login(email, password);

      if (result['success'] == true) {
        final data = result['data'];
        final token = data['token'] ?? data['access_token'];
        final user = data['user'] ?? data['data'] ?? {};

        // Clear ALL previous user data before saving new user
        await _storage.clearAll();
        
        // Save new user data
        await _storage.saveAuthToken(token.toString());
        await _storage.saveUserId(user['id']?.toString() ?? '');
        await _storage.saveUserEmail(user['email'] ?? email);
        await _storage.saveUserDisplayName(user['name'] ?? user['full_name'] ?? '');
        await _storage.saveUserRole('patient');

        final userPin = await _storage.getUserPin();
        final hasPin = userPin != null;

        state = AuthState.authenticated(
          userId: user['id']?.toString() ?? '',
          email: user['email'] ?? email,
          displayName: user['name'] ?? user['full_name'] ?? '',
          hasPin: hasPin,
          role: 'patient',
        );

        return true;
      } else {
        state = AuthState.error(result['error'] ?? 'Login failed');
        return false;
      }
    } catch (e) {
      state = AuthState.error('Login error: ${e.toString()}');
      return false;
    }
  }

  Future<bool> loginDoctor(String email, String password) async {
    state = AuthState.loading();

    try {
      final result = await _api.loginDoctor(email, password);

      if (result['success'] == true) {
        final data = result['data'];
        final token = data['token'] ?? data['access_token'];
        final user = data['user'] ?? data['data'] ?? {};

        // Clear ALL previous user data before saving new user
        await _storage.clearAll();
        
        // Save new user data
        await _storage.saveAuthToken(token.toString());
        await _storage.saveUserId(user['id']?.toString() ?? '');
        await _storage.saveUserEmail(user['email'] ?? email);
        await _storage.saveUserDisplayName(user['full_name'] ?? user['name'] ?? 'Dr. Unknown');
        await _storage.saveUserRole('doctor');

        state = AuthState.authenticated(
          userId: user['id']?.toString() ?? '',
          email: user['email'] ?? email,
          displayName: user['full_name'] ?? user['name'] ?? 'Dr. Unknown',
          hasPin: false,
          role: 'doctor',
        );

        return true;
      } else {
        state = AuthState.error(result['error'] ?? 'Doctor login failed');
        return false;
      }
    } catch (e) {
      state = AuthState.error('Doctor login error: ${e.toString()}');
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    state = AuthState.loading();

    try {
      final result = await _api.register(userData);

      if (result['success'] == true) {
        final data = result['data'];
        final token = data['token'] ?? data['access_token'];
        final user = data['user'] ?? data['data'] ?? {};

        // Clear ALL previous user data before saving new user
        await _storage.clearAll();
        
        // Save new user data
        await _storage.saveAuthToken(token.toString());
        await _storage.saveUserId(user['id']?.toString() ?? '');
        await _storage.saveUserEmail(user['email'] ?? userData['email']);
        await _storage.saveUserRole('patient');
        
        final fullName = user['full_name'] ?? 
                         '${userData['first_name']} ${userData['last_name']}';
        await _storage.saveUserDisplayName(fullName);

        state = AuthState.authenticated(
          userId: user['id']?.toString() ?? '',
          email: user['email'] ?? userData['email'],
          displayName: fullName,
          hasPin: false,
          role: 'patient',
        );

        return true;
      } else {
        state = AuthState.error(result['error'] ?? 'Registration failed');
        return false;
      }
    } catch (e) {
      state = AuthState.error('Registration error: ${e.toString()}');
      return false;
    }
  }

  Future<bool> setupPin(String pin) async {
    try {
      await _storage.saveUserPin(pin);

      state = state.copyWith(
        hasPin: true,
      );

      return true;
    } catch (e) {
      state = AuthState.error('Failed to set up PIN: ${e.toString()}');
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final storedPin = await _storage.getUserPin();
      
      if (storedPin == pin) {
        return true;
      } else {
        state = AuthState.error('Invalid PIN');
        return false;
      }
    } catch (e) {
      state = AuthState.error('PIN verification error: ${e.toString()}');
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();

    try {
      await _storage.clearAll();
      state = AuthState.initial();
    } catch (e) {
      state = AuthState.error('Logout error: ${e.toString()}');
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final result = await _api.request(
        method: 'PUT',
        endpoint: '/user/update-profile',
        data: profileData,
      );

      if (result['success'] == true) {
        final data = result['data'];
        
        if (data['name'] != null) {
          await _storage.saveUserDisplayName(data['name']);
          state = state.copyWith(displayName: data['name']);
        }

        return true;
      } else {
        state = AuthState.error(result['error'] ?? 'Failed to update profile');
        return false;
      }
    } catch (e) {
      state = AuthState.error('Profile update error: ${e.toString()}');
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final result = await _api.request(
        method: 'POST',
        endpoint: '/user/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      if (result['success'] == true) {
        return true;
      } else {
        state = AuthState.error(result['error'] ?? 'Failed to change password');
        return false;
      }
    } catch (e) {
      state = AuthState.error('Password change error: ${e.toString()}');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<String?> getToken() async {
    return await _storage.getAuthToken();
  }

  bool get isAuthenticated => state.isAuthenticated;
  bool get hasPin => state.hasPin;
  String? get userRole => state.role;
  bool get isDoctor => state.role == 'doctor';
}