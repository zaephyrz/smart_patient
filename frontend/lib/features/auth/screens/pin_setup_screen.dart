import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../../../config/constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import 'login_screen.dart';

enum PinSetupState { enter, confirm, success, verify }

class PinSetupScreen extends ConsumerStatefulWidget {
  final bool isFirstTime;
  final String? email;

  const PinSetupScreen({
    super.key,
    this.isFirstTime = true,
    this.email,
  });

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  
  String _currentPin = '';
  String _enteredPin = '';
  bool _isLoading = false;
  bool _showError = false;
  String _errorMessage = '';
  int _attemptsLeft = AppConstants.maxPinAttempts;
  
  PinSetupState _setupState = PinSetupState.enter;

  @override
  void initState() {
    super.initState();
    _setupState = widget.isFirstTime ? PinSetupState.enter : PinSetupState.verify;
    _loadStoredPin();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStoredPin() async {
    if (!widget.isFirstTime) {
      final storage = StorageService();
      final storedPin = await storage.getUserPin();
      if (storedPin != null) {
        setState(() {
          _currentPin = storedPin;
        });
      }
    }
  }

  void _handlePinEntry(String pin) {
    setState(() {
      _enteredPin = pin;
      _showError = false;
      _errorMessage = '';
    });

    if (pin.length == AppConstants.pinLength) {
      _validatePin();
    }
  }

  void _validatePin() async {
    if (_enteredPin.length != AppConstants.pinLength) {
      setState(() {
        _showError = true;
        _errorMessage = 'PIN must be ${AppConstants.pinLength} digits';
      });
      return;
    }

    if (_setupState == PinSetupState.enter) {
      setState(() {
        _currentPin = _enteredPin;
        _setupState = PinSetupState.confirm;
        _enteredPin = '';
        _pinController.clear();
        _showError = false;
      });
      return;
    }

    if (_setupState == PinSetupState.confirm) {
      if (_enteredPin == _currentPin) {
        setState(() {
          _setupState = PinSetupState.success;
          _isLoading = true;
        });
        await _savePin(_enteredPin);
      } else {
        setState(() {
          _showError = true;
          _errorMessage = 'PINs do not match. Please try again.';
          _enteredPin = '';
          _pinController.clear();
          _setupState = PinSetupState.enter;
          _currentPin = '';
        });
      }
      return;
    }

    if (_setupState == PinSetupState.verify) {
      if (_enteredPin == _currentPin) {
        setState(() {
          _isLoading = true;
        });
        await _verifyPinSuccess();
      } else {
        setState(() {
          _attemptsLeft--;
          _showError = true;
          _errorMessage = _attemptsLeft > 0
              ? 'Incorrect PIN. $_attemptsLeft attempts remaining.'
              : 'Too many failed attempts. Please login again.';
          _enteredPin = '';
          _pinController.clear();
          
          if (_attemptsLeft == 0) {
            _handleMaxAttemptsExceeded();
          }
        });
      }
    }
  }

  Future<void> _savePin(String pin) async {
    try {
      final authNotifier = ref.read(authStateProvider.notifier);
      final success = await authNotifier.setupPin(pin);
      
      if (!success && mounted) {
        final error = ref.read(authErrorProvider);
        setState(() {
          _isLoading = false;
          _showError = true;
          _errorMessage = error ?? 'Failed to save PIN';
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
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isFirstTime 
                  ? 'PIN set up successfully! 🔒' 
                  : 'PIN verified successfully!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = 'Error saving PIN: ${e.toString()}';
      });
    }
  }

  Future<void> _verifyPinSuccess() async {
    ref.invalidate(userDisplayNameProvider);
    ref.invalidate(userDisplayNameWithFallbackProvider);
    ref.invalidate(userEmailProvider);
    ref.invalidate(hasPinProvider);
    ref.invalidate(userRoleProvider);
    ref.invalidate(isDoctorProvider);

    setState(() {
      _isLoading = false;
    });
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  void _handleMaxAttemptsExceeded() async {
    final storage = StorageService();
    await storage.clearAll();
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too many failed attempts. Please login again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final pinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.primaryBlue,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(
          color: _showError ? AppColors.error : (isDark ? Colors.grey.shade700 : AppColors.gray300),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!widget.isFirstTime)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDark ? Colors.white : AppColors.primaryBlue,
                        ),
                        onPressed: _goToLogin,
                        tooltip: 'Go to Login',
                      ),
                    ),
                  ),
                
                if (widget.isFirstTime && _setupState != PinSetupState.success)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _goToLogin,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.gray700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
                
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
                
                Text(
                  _getTitle(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.primaryBlue,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  _getSubtitle(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : AppColors.gray700,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                if (_setupState == PinSetupState.success)
                  _buildSuccessView(isDark)
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Form(
                        key: _formKey,
                        child: Pinput(
                          controller: _pinController,
                          focusNode: _pinFocusNode,
                          length: AppConstants.pinLength,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          obscuringCharacter: '•',
                          onChanged: _handlePinEntry,
                          defaultPinTheme: pinTheme,
                          focusedPinTheme: pinTheme.copyWith(
                            decoration: pinTheme.decoration?.copyWith(
                              border: Border.all(
                                color: AppColors.primaryBlue,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.35 : 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          errorPinTheme: pinTheme.copyWith(
                            decoration: pinTheme.decoration?.copyWith(
                              border: Border.all(
                                color: AppColors.error,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: isDark ? 0.35 : 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          submittedPinTheme: pinTheme.copyWith(
                            decoration: pinTheme.decoration?.copyWith(
                              color: isDark 
                                  ? AppColors.primaryBlue.withValues(alpha: 0.2)
                                  : AppColors.primaryBlue.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.primaryBlue,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      if (_showError)
                        Container(
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
                              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      if (!widget.isFirstTime && _setupState == PinSetupState.verify)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _attemptsLeft <= 2 
                                ? AppColors.error.withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF1E1E1E) : AppColors.gray100),
                            borderRadius: BorderRadius.circular(20),
                            border: isDark && _attemptsLeft > 2 
                                ? Border.all(color: Colors.grey.shade800)
                                : null,
                          ),
                          child: Text(
                            'Attempts remaining: $_attemptsLeft',
                            style: TextStyle(
                              color: _attemptsLeft <= 2 
                                  ? AppColors.error 
                                  : (isDark ? Colors.white70 : AppColors.gray700),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      if (_setupState == PinSetupState.enter && widget.isFirstTime)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _enteredPin = '';
                              _pinController.clear();
                              _showError = false;
                              _errorMessage = '';
                            });
                          },
                          child: Text(
                            'Clear PIN',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : AppColors.gray700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_circle,
            size: 60,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.isFirstTime ? 'PIN Set Successfully!' : 'PIN Verified!',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isFirstTime 
              ? 'Your PIN has been set up successfully.' 
              : 'You have been authenticated successfully.',
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.gray700,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        if (_isLoading) ...[
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppColors.primaryBlue),
        ],
      ],
    );
  }

  String _getTitle() {
    if (widget.isFirstTime) {
      switch (_setupState) {
        case PinSetupState.enter:
          return 'Set Up PIN';
        case PinSetupState.confirm:
          return 'Confirm PIN';
        case PinSetupState.success:
          return 'Success!';
        default:
          return 'Set Up PIN';
      }
    } else {
      return 'Enter PIN';
    }
  }

  String _getSubtitle() {
    if (widget.isFirstTime) {
      switch (_setupState) {
        case PinSetupState.enter:
          return 'Create a ${AppConstants.pinLength}-digit PIN for secure access';
        case PinSetupState.confirm:
          return 'Please confirm your PIN to continue';
        case PinSetupState.success:
          return 'Your PIN has been set up successfully.';
        default:
          return 'Create a ${AppConstants.pinLength}-digit PIN for secure access';
      }
    } else {
      return 'Enter your ${AppConstants.pinLength}-digit PIN to continue';
    }
  }
}