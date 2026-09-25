import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import 'login_screen.dart';
import 'pin_setup_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 12)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryBlue,
                ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  /// Validates Kenyan phone number format: +2547XXXXXXXX
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    
    // Remove all whitespace
    final cleanNumber = value.replaceAll(RegExp(r'\s+'), '');
    
    // Check if it starts with +254
    if (!cleanNumber.startsWith('+254')) {
      return 'Phone number must start with +254';
    }
    
    // Remove +254 prefix for further validation
    final numberWithoutPrefix = cleanNumber.substring(4);
    
    // Check if remaining digits are exactly 9 digits and start with 7
    if (!RegExp(r'^7[0-9]{8}$').hasMatch(numberWithoutPrefix)) {
      return 'Phone number must be +254 followed by 9 digits starting with 7';
    }
    
    return null;
  }

  /// Validates name (only letters, spaces, hyphens, and apostrophes)
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Please enter your $fieldName';
    }
    
    if (value.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value)) {
      return '$fieldName can only contain letters, spaces, hyphens, and apostrophes';
    }
    
    return null;
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }

      setState(() {
        _errorMessage = null;
        _successMessage = null;
      });

      final userData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'phone': _phoneController.text.trim(),
        'date_of_birth': _dateOfBirthController.text.trim(),
      };

      final authNotifier = ref.read(authStateProvider.notifier);
      final success = await authNotifier.register(userData);

      if (!success && mounted) {
        final error = ref.read(authErrorProvider);
        setState(() {
          _errorMessage = error ?? 'Registration failed. Please try again.';
        });
        return;
      }

      if (mounted) {
        ref.invalidate(userDisplayNameProvider);
        ref.invalidate(userDisplayNameWithFallbackProvider);
        ref.invalidate(userEmailProvider);
        ref.invalidate(hasPinProvider);
        ref.invalidate(userRoleProvider);
        ref.invalidate(isDoctorProvider);

        setState(() {
          _successMessage = 'Registration successful! Setting up security...';
        });
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PinSetupScreen(
                  isFirstTime: true,
                  email: _emailController.text.trim(),
                ),
              ),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final error = ref.watch(authErrorProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    if (error != null && _errorMessage == null) {
      setState(() {
        _errorMessage = error;
      });
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                    onPressed: isLoading ? null : () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
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
              
              const SizedBox(height: 20),
              
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
                'Create your account 🚀',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : AppColors.gray700,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Registration Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // First Name Field
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
                        controller: _firstNameController,
                        enabled: !isLoading,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : AppColors.gray700,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppColors.primaryBlue,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) => _validateName(value, 'First name'),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Last Name Field
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
                        controller: _lastNameController,
                        enabled: !isLoading,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : AppColors.gray700,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppColors.primaryBlue,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) => _validateName(value, 'Last name'),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Email Field
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
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : AppColors.gray700,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: AppColors.primaryBlue,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email address';
                          }
                          // RFC 5322 compliant email regex
                          if (!RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$").hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Phone Field - FIXED with proper Kenyan format validation
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
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !isLoading,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : AppColors.gray700,
                          ),
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            color: AppColors.primaryBlue,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          hintText: '+254712345678',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white60 : AppColors.gray700,
                          ),
                        ),
                        validator: _validatePhoneNumber,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Date of Birth Field
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: TextFormField(
                            controller: _dateOfBirthController,
                            enabled: false,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : AppColors.gray700,
                              ),
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: AppColors.primaryBlue,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              hintText: 'Select your date of birth',
                              hintStyle: TextStyle(
                                color: _dateOfBirthController.text.isEmpty 
                                    ? (isDark ? Colors.white60 : AppColors.gray700)
                                    : (isDark ? Colors.white : AppColors.black),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your date of birth';
                              }
                              try {
                                final dob = DateTime.parse(value);
                                final now = DateTime.now();
                                final age = now.year - dob.year - 
                                    ((now.month < dob.month || 
                                      (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
                                if (age < 12) {
                                  return 'You must be at least 12 years old to register';
                                }
                                if (age > 120) {
                                  return 'Please enter a valid date of birth';
                                }
                              } catch (e) {
                                return 'Invalid date format';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
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
                        enabled: !isLoading,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password',
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
                          helperText: 'Must be at least ${AppConstants.minPasswordLength} characters',
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
                          // Check for at least one number and one letter
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
                        enabled: !isLoading,
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
                    
                    // Success Message
                    if (_successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.success, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Create Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(
                            color: isLoading 
                                ? (isDark ? Colors.white30 : AppColors.gray300)
                                : (isDark ? Colors.white70 : AppColors.gray700),
                          ),
                        ),
                        TextButton(
                          onPressed: isLoading ? null : () {
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
                            'Login Here',
                            style: TextStyle(
                              color: isLoading 
                                  ? (isDark ? Colors.white30 : AppColors.gray300)
                                  : AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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