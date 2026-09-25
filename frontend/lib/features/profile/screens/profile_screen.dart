import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/avatar_selector.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userEmail = ref.watch(userEmailProvider) ?? 'No email';
    final displayName = ref.watch(userDisplayNameProvider) ?? 'User';
    final hasPin = ref.watch(hasPinProvider);
    final isLoading = ref.watch(authLoadingProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
        foregroundColor: isDark ? Colors.white : AppColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.primaryGreen.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      FutureBuilder<String?>(
                        future: StorageService().getUserAvatarPath(),
                        builder: (context, snapshot) {
                          final avatarValue = snapshot.data;
                          final isInitials = avatarValue != null &&
                              RegExp(r'^[A-Z]{2}$').hasMatch(avatarValue);
                          final hasImageAvatar = avatarValue != null &&
                              !isInitials &&
                              File(avatarValue).existsSync();

                          return CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: hasImageAvatar
                                ? FileImage(File(avatarValue))
                                : null,
                            child: !hasImageAvatar
                                ? Text(
                                    isInitials
                                        ? avatarValue
                                        : (displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : 'U'),
                                    style: GoogleFonts.poppins(
                                      fontSize: isInitials ? 28 : 36,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: GestureDetector(
                            onTap: () => _showAvatarSelector(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasPin ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasPin ? '🔒 PIN Enabled' : '🔓 PIN Not Set',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionLabel(context, 'Preferences', isDark),
            const SizedBox(height: 8),
            Container(
              decoration: _cardDecoration(context, isDark),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              color: AppColors.primaryBlue,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dark Mode',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : AppColors.black,
                                  ),
                                ),
                                Text(
                                  isDark ? 'Enabled' : 'Disabled',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : AppColors.gray700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              ref.read(themeModeProvider.notifier).setDarkMode(!isDark);
                            },
                            child: Container(
                              width: 56,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isDark ? AppColors.primaryBlue : Colors.grey.shade300,
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark 
                                        ? AppColors.primaryBlue.withValues(alpha: 0.3)
                                        : Colors.grey.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 200),
                                alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isDark ? Icons.dark_mode : Icons.light_mode,
                                    size: 14,
                                    color: isDark ? AppColors.primaryBlue : Colors.grey.shade600,
                                  ),
                                ),
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

            const SizedBox(height: 20),

            _buildSectionLabel(context, 'Account', isDark),
            const SizedBox(height: 8),
            Container(
              decoration: _cardDecoration(context, isDark),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    _buildProfileTile(
                      context,
                      icon: Icons.photo_library,
                      title: 'Change Avatar',
                      subtitle: 'Update your profile picture',
                      color: Colors.purple,
                      isDark: isDark,
                      onTap: () => _showAvatarSelector(context),
                    ),
                    _buildDivider(isDark),
                    _buildProfileTile(
                      context,
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      subtitle: 'Update your security password',
                      color: AppColors.primaryBlue,
                      isDark: isDark,
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                    _buildDivider(isDark),
                    _buildProfileTile(
                      context,
                      icon: Icons.pin,
                      title: 'Change PIN',
                      subtitle: 'Update your security PIN',
                      color: Colors.orange,
                      isDark: isDark,
                      onTap: () => _showChangePinDialog(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionLabel(context, 'Support', isDark),
            const SizedBox(height: 8),
            Container(
              decoration: _cardDecoration(context, isDark),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    _buildProfileTile(
                      context,
                      icon: Icons.help_outline,
                      title: 'Contact Support',
                      subtitle: 'Get help and support',
                      color: AppColors.info,
                      isDark: isDark,
                      onTap: () => _showContactSupport(context),
                    ),
                    _buildDivider(isDark),
                    _buildProfileTile(
                      context,
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      color: AppColors.error,
                      isDark: isDark,
                      onTap: () => _showLogoutDialog(context, ref),
                      isLogout: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context, bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : AppColors.gray700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildProfileTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isLogout ? AppColors.error : color,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout 
              ? AppColors.error 
              : (isDark ? Colors.white : AppColors.black),
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white70 : AppColors.gray700,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        isLogout ? Icons.logout : Icons.arrow_forward_ios,
        color: isLogout 
            ? AppColors.error 
            : (isDark ? Colors.white60 : AppColors.gray700),
        size: 18,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.grey.shade800 : AppColors.gray200,
      indent: 16,
      endIndent: 16,
    );
  }

  void _showAvatarSelector(BuildContext context) async {
    final currentAvatar = await StorageService().getUserAvatarPath();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: AvatarSelector(
          currentAvatar: currentAvatar,
          onAvatarSelected: (avatar) {
            StorageService().saveUserAvatarPath(avatar);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Avatar updated successfully!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Change Password',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.primaryBlue,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPasswordField(
                    controller: currentPasswordController,
                    label: 'Current Password',
                    obscure: obscureCurrent,
                    isDark: isDark,
                    onToggle: () => setState(() => obscureCurrent = !obscureCurrent),
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    controller: newPasswordController,
                    label: 'New Password',
                    obscure: obscureNew,
                    isDark: isDark,
                    onToggle: () => setState(() => obscureNew = !obscureNew),
                    helperText: 'Must be at least ${AppConstants.minPasswordLength} characters',
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    controller: confirmPasswordController,
                    label: 'Confirm Password',
                    obscure: obscureConfirm,
                    isDark: isDark,
                    onToggle: () => setState(() => obscureConfirm = !obscureConfirm),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.gray700,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final currentPassword = currentPasswordController.text.trim();
                  final newPassword = newPasswordController.text.trim();
                  final confirmPassword = confirmPasswordController.text.trim();

                  if (currentPassword.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your current password'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  if (newPassword.length < AppConstants.minPasswordLength) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password must be at least 8 characters'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  if (newPassword != confirmPassword) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Passwords do not match'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  setState(() => isLoading = true);

                  try {
                    final authNotifier = ref.read(authStateProvider.notifier);
                    final success = await authNotifier.changePassword(
                      currentPassword,
                      newPassword,
                    );

                    if (success && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password changed successfully! 🔒'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      );
                    } else if (context.mounted) {
                      final error = ref.read(authErrorProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error ?? 'Failed to change password'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  } finally {
                    if (context.mounted) setState(() => isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Update Password',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required bool isDark,
    required VoidCallback onToggle,
    String? helperText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.white70 : AppColors.gray700,
          ),
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: AppColors.primaryBlue,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility : Icons.visibility_off,
              color: isDark ? Colors.white70 : AppColors.gray700,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          helperText: helperText,
          helperStyle: TextStyle(
            color: isDark ? Colors.white60 : AppColors.gray700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Change PIN',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.primaryBlue,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your current PIN and new PIN',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.gray700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPinField(
                    controller: currentPinController,
                    label: 'Current PIN',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildPinField(
                    controller: newPinController,
                    label: 'New PIN',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildPinField(
                    controller: confirmPinController,
                    label: 'Confirm PIN',
                    isDark: isDark,
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.gray700,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final currentPin = currentPinController.text.trim();
                  final newPin = newPinController.text.trim();
                  final confirmPin = confirmPinController.text.trim();

                  if (currentPin.length != AppConstants.pinLength) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PIN must be 4 digits'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  if (newPin.length != AppConstants.pinLength) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('New PIN must be 4 digits'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  if (newPin != confirmPin) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PINs do not match'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  setState(() => isLoading = true);

                  try {
                    final storage = StorageService();
                    final storedPin = await storage.getUserPin();

                    if (storedPin != currentPin) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Current PIN is incorrect'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      setState(() => isLoading = false);
                      return;
                    }

                    await storage.saveUserPin(newPin);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PIN changed successfully! 🔒'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  } finally {
                    if (context.mounted) setState(() => isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Update PIN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: true,
        maxLength: AppConstants.pinLength,
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.white70 : AppColors.gray700,
          ),
          prefixIcon: const Icon(Icons.pin, color: AppColors.primaryBlue),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  void _showContactSupport(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Contact Support',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.primaryBlue,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How can we help you?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: isDark ? Colors.white : AppColors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildSupportOption(
              context,
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'info@smartmedicalhub.com',
              color: AppColors.primaryBlue,
              isDark: isDark,
              onTap: () => _launchEmail('info@smartmedicalhub.com'),
            ),
            Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            _buildSupportOption(
              context,
              icon: Icons.phone_outlined,
              title: 'Phone Support',
              subtitle: '+254 759 667 667',
              color: AppColors.primaryGreen,
              isDark: isDark,
              onTap: () => _launchPhone('+254759667667'),
            ),
            Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            _buildSupportOption(
              context,
              icon: Icons.language_outlined,
              title: 'Visit Website',
              subtitle: 'www.smartmedicalhub.com',
              color: AppColors.accentBlue,
              isDark: isDark,
              onTap: () => _launchURL('https://www.smartmedicalhub.com'),
            ),
            Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            _buildSupportOption(
              context,
              icon: Icons.help_outline,
              title: 'FAQ',
              subtitle: 'Frequently asked questions',
              color: AppColors.accentGreen,
              isDark: isDark,
              onTap: () => _showFAQ(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.gray700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.gray700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDark ? Colors.white60 : AppColors.gray700,
            ),
          ],
        ),
      ),
    );
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Smart%20Medical%20Hub%20Support',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }
    } catch (_) {}
  }

  void _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (_) {}
  }

  void _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showFAQ(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Frequently Asked Questions',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.primaryBlue,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFAQItem(
              'How do I book an appointment?',
              'Go to the Dashboard and tap "Book Appointment".',
              isDark,
            ),
            _buildFAQItem(
              'How do I reset my password?',
              'On the login screen, tap "Forgot Password".',
              isDark,
            ),
            _buildFAQItem(
              'Is my data secure?',
              'Yes, all your medical data is encrypted and stored securely.',
              isDark,
            ),
            _buildFAQItem(
              'How do I join a telemedicine call?',
              'Tap "Telemedicine" on the Dashboard and enter the room ID.',
              isDark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.gray700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.white : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            answer,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : AppColors.gray700,
            ),
          ),
          Divider(height: 12, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Logout',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.gray700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authNotifier = ref.read(authStateProvider.notifier);
      await authNotifier.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    }
  }
}