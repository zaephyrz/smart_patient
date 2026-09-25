import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../../config/constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/widgets/dashboard_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../appointments/screens/appointments_screen.dart';
import '../../appointments/screens/book_appointment_screen.dart';
import '../../medical_records/screens/records_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../telemedicine/screens/telemedicine_home_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    DashboardContent(),
    AppointmentsScreen(),
    MedicalRecordsScreen(showBackButton: false),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final showTopBar = _currentIndex != 3;

    return Scaffold(
      appBar: showTopBar 
          ? const AppTopBar(title: 'Smart Patient')
          : null,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.gray700,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardContent extends ConsumerStatefulWidget {
  const DashboardContent({super.key});

  @override
  ConsumerState<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<DashboardContent> {
  bool _isLoadingStats = true;
  bool _isLoadingActivity = true;
  int _appointmentsCount = 0;
  int _recordsCount = 0;
  int _telemedicineCount = 0;
  List<ActivityItem> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
  if (!mounted) return;
  setState(() {
    _isLoadingStats = true;
    _isLoadingActivity = true;
  });

  try {
    final token = await StorageService().getAuthToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _appointmentsCount = 0;
          _recordsCount = 0;
          _telemedicineCount = 0;
          _recentActivities = [];
          _isLoadingStats = false;
          _isLoadingActivity = false;
        });
      }
      return;
    }

    // Load appointments and records in parallel
    final results = await Future.wait([
      ApiService().request(method: 'GET', endpoint: '/appointments'),
      ApiService().getMedicalRecords(token: token),
    ]);

    final appointmentsResponse = results[0];
    final recordsResponse = results[1];

    // Process appointments
    int appointmentsCount = 0;
    int telemedicineCount = 0;
    List<Map<String, dynamic>> appointmentsList = [];
    
    if (appointmentsResponse['success'] == true) {
      // Try new format first
      if (appointmentsResponse['appointments'] != null) {
        final aptData = appointmentsResponse['appointments'];
        if (aptData is List) {
          appointmentsList = List<Map<String, dynamic>>.from(aptData);
        }
      } 
      // Fallback to old format
      else if (appointmentsResponse['data'] != null) {
        final data = appointmentsResponse['data'];
        if (data is List) {
          appointmentsList = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['appointments'] != null) {
          final aptData = data['appointments'];
          if (aptData is List) {
            appointmentsList = List<Map<String, dynamic>>.from(aptData);
          }
        }
      }
      
      appointmentsCount = appointmentsList.length;
      telemedicineCount = appointmentsList.where((apt) {
        final type = apt['consultation_type']?.toString().toLowerCase();
        return type == 'telemedicine';
      }).length;
    }

    // Process records - FIX: correctly parse the records count
    int recordsCount = 0;
    if (recordsResponse['success'] == true) {
      final data = recordsResponse['data'];
      if (data is List) {
        recordsCount = data.length;
      } else if (data is Map) {
        // Check for medical_records key
        if (data['medical_records'] != null) {
          final records = data['medical_records'];
          if (records is List) {
            recordsCount = records.length;
          }
        } else if (data['data'] != null) {
          // Nested data
          final nestedData = data['data'];
          if (nestedData is List) {
            recordsCount = nestedData.length;
          } else if (nestedData is Map && nestedData['medical_records'] != null) {
            final records = nestedData['medical_records'];
            if (records is List) {
              recordsCount = records.length;
            }
          }
        }
      }
    }

    // Build recent activities from appointments
    final now = DateTime.now();
    final List<ActivityItem> activities = [];
    
    // Sort appointments by date (most recent first)
    appointmentsList.sort((a, b) {
      final dateA = DateTime.tryParse(a['appointment_date'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['appointment_date'] ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    // Take up to 3 most recent appointments
    for (var apt in appointmentsList.take(3)) {
      final date = DateTime.tryParse(apt['appointment_date'] ?? '');
      if (date == null) continue;
      
      final isPast = date.isBefore(now);
      final status = apt['status']?.toString() ?? 'scheduled';
      final doctorName = apt['doctor_name'] ?? 'Dr. Unknown';
      final isTelemedicine = apt['consultation_type']?.toString().toLowerCase() == 'telemedicine';
      
      String title;
      String subtitle;
      IconData icon;
      Color color;
      
      if (isPast) {
        title = 'Past Appointment';
        subtitle = '${DateFormat('MMM dd, yyyy').format(date)} with $doctorName';
        icon = Icons.history;
        color = AppColors.gray700;
      } else if (status.toLowerCase() == 'confirmed') {
        title = 'Upcoming Appointment';
        subtitle = '${DateFormat('MMM dd, yyyy').format(date)} at ${DateFormat('hh:mm a').format(date)} with $doctorName';
        icon = isTelemedicine ? Icons.video_call : Icons.medical_services;
        color = AppColors.primaryBlue;
      } else {
        title = 'Appointment';
        subtitle = '${DateFormat('MMM dd, yyyy').format(date)} with $doctorName';
        icon = Icons.calendar_today;
        color = AppColors.warning;
      }
      
      // Calculate relative time
      final diff = now.difference(date);
      String timeAgo;
      if (diff.inDays > 30) {
        timeAgo = '${diff.inDays ~/ 30} months ago';
      } else if (diff.inDays > 7) {
        timeAgo = '${diff.inDays ~/ 7} weeks ago';
      } else if (diff.inDays > 1) {
        timeAgo = '${diff.inDays} days ago';
      } else if (diff.inDays == 1) {
        timeAgo = 'Yesterday';
      } else if (diff.inHours > 1) {
        timeAgo = '${diff.inHours} hours ago';
      } else if (diff.inHours == 1) {
        timeAgo = '1 hour ago';
      } else if (diff.inMinutes > 1) {
        timeAgo = '${diff.inMinutes} minutes ago';
      } else {
        timeAgo = 'Just now';
      }
      
      activities.add(ActivityItem(
        icon: icon,
        title: title,
        subtitle: subtitle,
        time: timeAgo,
        color: color,
      ));
    }

    // If no activities, add some default ones
    if (activities.isEmpty) {
      activities.addAll([
        ActivityItem(
          icon: Icons.medical_services,
          title: 'No Upcoming Appointments',
          subtitle: 'Book your first appointment to get started',
          time: 'Book now',
          color: AppColors.primaryBlue,
        ),
        ActivityItem(
          icon: Icons.folder,
          title: 'Medical Records',
          subtitle: 'Your records will appear here',
          time: 'View',
          color: AppColors.accentBlue,
        ),
      ]);
    }

    if (mounted) {
      setState(() {
        _appointmentsCount = appointmentsCount;
        _recordsCount = recordsCount;
        _telemedicineCount = telemedicineCount;
        _recentActivities = activities;
        _isLoadingStats = false;
        _isLoadingActivity = false;
      });
    }
  } catch (e) {
    debugPrint('Error loading dashboard data: $e');
    if (mounted) {
      setState(() {
        _appointmentsCount = 0;
        _recordsCount = 0;
        _telemedicineCount = 0;
        _recentActivities = [];
        _isLoadingStats = false;
        _isLoadingActivity = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final displayName = ref.watch(userDisplayNameWithFallbackProvider);
    final userEmail = ref.watch(userEmailProvider) ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final timeOfDay = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section with Gradient Background
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar with sync from storage
                    FutureBuilder<String?>(
                      future: StorageService().getUserAvatarPath(),
                      builder: (context, snapshot) {
                        final avatarValue = snapshot.data;
                        final isInitials = avatarValue != null &&
                            RegExp(r'^[A-Z]{2}$').hasMatch(avatarValue);
                        final hasImageAvatar = avatarValue != null &&
                            !isInitials &&
                            File(avatarValue).existsSync();

                        return Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            image: hasImageAvatar
                                ? DecorationImage(
                                    image: FileImage(File(avatarValue)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: !hasImageAvatar
                              ? Center(
                                  child: Text(
                                    isInitials
                                        ? avatarValue
                                        : (displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : 'U'),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: isInitials ? 20 : 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$timeOfDay,',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            displayName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            userEmail,
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Quick stats — real counts for this logged-in patient
                Row(
                  children: [
                    _buildQuickStat(
                      icon: Icons.medical_services,
                      value: '$_appointmentsCount',
                      label: 'Appointments',
                      isLoading: _isLoadingStats,
                    ),
                    const SizedBox(width: 20),
                    _buildQuickStat(
                      icon: Icons.folder,
                      value: '$_recordsCount',
                      label: 'Records',
                      isLoading: _isLoadingStats,
                    ),
                    const SizedBox(width: 20),
                    _buildQuickStat(
                      icon: Icons.video_call,
                      value: '$_telemedicineCount',
                      label: 'Calls',
                      isLoading: _isLoadingStats,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.1,
            children: [
              DashboardCard(
                icon: Icons.calendar_today,
                title: 'Book\nAppointment',
                color: const Color(0xFF4A90D9),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookAppointmentScreen(),
                    ),
                  );
                },
              ),
              DashboardCard(
                icon: Icons.video_call,
                title: 'Telemedicine',
                color: const Color(0xFF27AE60),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TelemedicineHomeScreen(),
                    ),
                  );
                },
                badgeText: 'LIVE',
                badgeColor: const Color(0xFFE74C3C),
              ),
              DashboardCard(
                icon: Icons.folder,
                title: 'Medical\nRecords',
                color: const Color(0xFF8E44AD),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MedicalRecordsScreen(showBackButton: true),
                    ),
                  );
                },
              ),
              DashboardCard(
                icon: Icons.person,
                title: 'Profile',
                color: const Color(0xFFE67E22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Activity Section - Now with real data
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.primaryBlue,
                      ),
                    ),
                    if (_isLoadingActivity)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingActivity)
                  _buildShimmerActivityItems()
                else if (_recentActivities.isEmpty)
                  _buildEmptyActivity(isDark)
                else
                  ..._recentActivities.asMap().entries.map((entry) {
                    final index = entry.key;
                    final activity = entry.value;
                    return Column(
                      children: [
                        _buildActivityItem(
                          icon: activity.icon,
                          title: activity.title,
                          subtitle: activity.subtitle,
                          time: activity.time,
                          color: activity.color,
                          isDark: isDark,
                        ),
                        if (index < _recentActivities.length - 1)
                          Divider(
                            height: 16,
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          ),
                      ],
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Health Tip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF6B6B),
                  Color(0xFFFF8E53),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health Tip 💡',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Stay hydrated! Drink at least 8 glasses of water daily for optimal health.',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildShimmerActivityItems() {
    return Column(
      children: List.generate(3, (index) => Column(
        children: [
          Row(
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 200,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: 50,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          if (index < 2)
            Divider(
              height: 16,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade200,
            ),
        ],
      )),
    );
  }

  Widget _buildEmptyActivity(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: isDark ? Colors.grey.shade600 : AppColors.gray300,
            ),
            const SizedBox(height: 8),
            Text(
              'No recent activity',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.gray700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your activities will appear here',
              style: TextStyle(
                color: isDark ? Colors.white60 : AppColors.gray700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String value,
    required String label,
    required bool isLoading,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isLoading
                ? Shimmer.fromColors(
                    baseColor: Colors.white24,
                    highlightColor: Colors.white70,
                    child: Container(
                      width: 18,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppColors.gray700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: isDark ? Colors.white60 : AppColors.gray700,
          ),
        ),
      ],
    );
  }
}

// Helper class for activity items
class ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}