import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/constants.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final merged = await ref.refresh(notificationsProvider.future);
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(merged);
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id) async {
    await StorageService().markLocalNotificationAsRead(id);

    try {
      await ApiService().request(
        method: 'PUT',
        endpoint: '/notifications/$id/read',
      );
    } catch (_) {}
    
    if (mounted) {
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'].toString() == id.toString());
        if (index != -1) {
          _notifications[index]['is_read'] = 1;
        }
      });
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  Future<void> _markAllAsRead() async {
    await StorageService().markAllLocalNotificationsAsRead();

    try {
      await ApiService().request(
        method: 'PUT',
        endpoint: '/notifications/read-all',
      );
    } catch (_) {}
    
    if (mounted) {
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = 1;
        }
      });
      ref.invalidate(unreadNotificationCountProvider);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All notifications marked as read'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Clear / Delete all notifications
  Future<void> _clearAllNotifications() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Clear Notifications', style: TextStyle(color: isDark ? Colors.white : AppColors.black)),
        content: Text('Are you sure you want to clear all notifications?', style: TextStyle(color: isDark ? Colors.white70 : AppColors.gray700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : AppColors.gray700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_local_notifications');
      
      setState(() {
        _notifications.clear();
      });
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(notificationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
        foregroundColor: isDark ? Colors.white : AppColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                Icons.done_all,
                color: isDark ? Colors.white : AppColors.primaryBlue,
              ),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.error,
              ),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear all notifications',
            ),
          ],
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : AppColors.primaryBlue,
            ),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryBlue,
              ),
            )
          : _notifications.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _buildNotificationCard(notification, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : AppColors.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off,
              size: 50,
              color: isDark ? Colors.grey.shade600 : AppColors.gray300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.gray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, bool isDark) {
    final bool isRead = notification['is_read'] == 1 || notification['is_read'] == true;
    final Color typeColor = _getTypeColor(notification['type']);
    final DateTime createdAt = DateTime.tryParse(notification['created_at']?.toString() ?? '') ?? DateTime.now();
    final int notifId = int.tryParse(notification['id'].toString()) ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead 
            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
            : (isDark 
                ? Color.alphaBlend(AppColors.primaryBlue.withValues(alpha: 0.18), const Color(0xFF1E1E1E))
                : AppColors.primaryBlue.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(16),
        border: isRead 
            ? null 
            : Border.all(
                color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.4 : 0.3),
                width: 1.5,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!isRead) {
              _markAsRead(notifId);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getTypeIcon(notification['type']),
                    color: typeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'] ?? 'Notification',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'] ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.gray700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy hh:mm a').format(createdAt),
                        style: TextStyle(
                          color: isDark ? Colors.white60 : AppColors.gray700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, left: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'appointment':
        return AppColors.primaryBlue;
      case 'medical':
        return AppColors.primaryGreen;
      case 'telemedicine':
        return Colors.purple;
      case 'alert':
        return AppColors.error;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'appointment':
        return Icons.calendar_today;
      case 'medical':
        return Icons.folder;
      case 'telemedicine':
        return Icons.video_call;
      case 'alert':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }
}