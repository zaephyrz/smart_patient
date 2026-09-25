import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/api_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.token,
    required this.email,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSuccess = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      try {
        final result = await ApiService().request(
          method: 'POST',
          endpoint: '/auth/reset-password',
          data: {
            'token': widget.token,
            'new_password': _passwordController.text.trim(),
          },
        );

        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          setState(() {
            _isSuccess = true;
            _successMessage = result['message'] ?? 'Password reset successfully!';
          });
          
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            }
          });
        } else {
          setState(() {
            _errorMessage = result['error']?.toString() ?? 'Failed to reset password. Please try again.';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white : AppColors.primaryBlue,
                    ),
                    onPressed: _isLoading ? null : () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Logo with Blue-Green Gradient
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.primaryGreen,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 60,
                    height: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // App Name
              Text(
                AppConstants.appName,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryBlue,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Reset Password 🔑',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : AppColors.gray700,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Enter your new password for ${widget.email}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.gray700,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Success View
              if (_isSuccess)
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 50,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _successMessage ?? 'Password Reset Successful!',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Redirecting to login...',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.gray700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ],
                )
              else
                // Reset Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Password Field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          enabled: !_isLoading,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : AppColors.gray700,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppColors.primaryBlue,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible 
                                    ? Icons.visibility_off 
                                    : Icons.visibility,
                                color: isDark ? Colors.white70 : AppColors.gray700,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            helperText: 'Must be at least ${AppConstants.minPasswordLength} characters with at least one letter and one number',
                            helperStyle: TextStyle(
                              color: isDark ? Colors.white60 : AppColors.gray700,
                              fontSize: 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < AppConstants.minPasswordLength) {
                              return 'Password must be at least ${AppConstants.minPasswordLength} characters';
                            }
                            if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                              return 'Password must contain at least one letter and one number';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Confirm Password Field
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_confirmPasswordVisible,
                          enabled: !_isLoading,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : AppColors.gray700,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppColors.primaryBlue,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _confirmPasswordVisible 
                                    ? Icons.visibility_off 
                                    : Icons.visibility,
                                color: isDark ? Colors.white70 : AppColors.gray700,
                              ),
                              onPressed: () {
                                setState(() {
                                  _confirmPasswordVisible = !_confirmPasswordVisible;
                                });
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      // Error Message
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // Reset Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Reset Password',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Back to Login Link
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          'Back to Login',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}