import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/storage_service.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/notifications/screens/notification_screen.dart';
import '../widgets/notification_badge.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBackButton;
  final List<Widget>? actions;

  const AppTopBar({
    super.key,
    this.title,
    this.showBackButton = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(userDisplayNameWithFallbackProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: isDark ? Colors.white : AppColors.black,
              ),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryGreen,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                color: Colors.white,
                width: 32,
                height: 32,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (title != null)
            Text(
              title!,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.black,
              ),
            ),
        ],
      ),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      foregroundColor: isDark ? Colors.white : AppColors.black,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF121212),
                    const Color(0xFF1A1A2E),
                  ]
                : [
                    Colors.white,
                    Colors.blue.shade50,
                  ],
          ),
        ),
      ),
      actions: [
        ...?actions,
        NotificationBadge(
          child: IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: isDark ? Colors.white : AppColors.black,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
            child: FutureBuilder<String?>(
              future: StorageService().getUserAvatarPath(),
              builder: (context, snapshot) {
                final avatarPath = snapshot.data;
                final isInitials = avatarPath != null &&
                    RegExp(r'^[A-Z]{2}$').hasMatch(avatarPath);
                final hasImageAvatar = avatarPath != null &&
                    !isInitials &&
                    File(avatarPath).existsSync();

                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.primaryGreen,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: hasImageAvatar
                        ? Image.file(File(avatarPath), fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              isInitials
                                  ? avatarPath
                                  : (displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'U'),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: isInitials ? 12 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}