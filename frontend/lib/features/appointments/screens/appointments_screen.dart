import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:clipboard/clipboard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/v_call_helper.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../screens/book_appointment_screen.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  bool _isLoading = false;
  bool _isListView = true;
  List<Appointment> _calendarAppointments = [];
  List<AppointmentData> _upcomingAppointments = [];
  List<AppointmentData> _pastAppointments = [];
  
  final Map<String, String> _doctorImages = {};

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await StorageService().getAuthToken();
      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doctorsResponse = await ApiService().request(
        method: 'GET',
        endpoint: '/doctors',
      );
      
      if (doctorsResponse['success'] == true) {
        final doctors = doctorsResponse['data'] ?? doctorsResponse['doctors'] ?? [];
        for (var doctor in doctors) {
          final doctorId = doctor['id']?.toString();
          final profileImage = doctor['profile_image'];
          if (doctorId != null && profileImage != null && profileImage.isNotEmpty) {
            _doctorImages[doctorId] = profileImage;
          }
        }
      }

      final response = await ApiService().request(
        method: 'GET',
        endpoint: '/appointments',
      );

      if (response['appointments'] != null) {
        final List<dynamic> appointmentsData = response['appointments'] as List;
        
        final now = DateTime.now();
        _upcomingAppointments = [];
        _pastAppointments = [];

        for (var json in appointmentsData) {
          final apt = AppointmentData.fromJson(json, _doctorImages);
          final normalizedStatus = _normalizeStatus(apt.status);
          
          if (normalizedStatus == 'Cancelled' || apt.dateTime.isBefore(now)) {
            _pastAppointments.add(apt);
          } else {
            _upcomingAppointments.add(apt);
          }
        }

        _upcomingAppointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        _pastAppointments.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        _calendarAppointments = [
          ..._upcomingAppointments.map((apt) => Appointment(
            startTime: apt.dateTime,
            endTime: apt.dateTime.add(const Duration(minutes: 30)),
            subject: '${apt.doctorName} - ${apt.specialty}',
            color: _getStatusColor(apt.status),
          )),
          ..._pastAppointments.map((apt) => Appointment(
            startTime: apt.dateTime,
            endTime: apt.dateTime.add(const Duration(minutes: 30)),
            subject: '${apt.doctorName} - ${apt.specialty}',
            color: _getStatusColor(apt.status),
          )),
        ];
        
        ref.invalidate(unreadNotificationCountProvider);
      } else {
        _loadMockData();
      }
    } catch (e) {
      debugPrint('Error loading appointments: $e');
      _loadMockData();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _loadMockData() {
    final now = DateTime.now();
    _upcomingAppointments = [
      AppointmentData(
        id: '1',
        doctorName: 'Dr. Jane Smith',
        specialty: 'Cardiology',
        dateTime: now.add(const Duration(days: 1, hours: 10)),
        status: 'Confirmed',
        type: 'telemedicine',
        hospital: 'City General Hospital',
        telemedicineRoomId: 'SMH-91622',
      ),
    ];

    _pastAppointments = [
      AppointmentData(
        id: '2',
        doctorName: 'Dr. Michael Johnson',
        specialty: 'Neurology',
        dateTime: now.subtract(const Duration(days: 3, hours: 14)),
        status: 'Cancelled',
        type: 'telemedicine',
        hospital: 'Neuro Health Institute',
        telemedicineRoomId: 'SMH-12345',
      ),
    ];

    _calendarAppointments = [
      ..._upcomingAppointments.map((apt) => Appointment(
        startTime: apt.dateTime,
        endTime: apt.dateTime.add(const Duration(minutes: 30)),
        subject: '${apt.doctorName} - ${apt.specialty}',
        color: _getStatusColor(apt.status),
      )),
      ..._pastAppointments.map((apt) => Appointment(
        startTime: apt.dateTime,
        endTime: apt.dateTime.add(const Duration(minutes: 30)),
        subject: '${apt.doctorName} - ${apt.specialty}',
        color: _getStatusColor(apt.status),
      )),
    ];
  }

  String _normalizeStatus(String status) {
    final lower = status.toLowerCase();
    if (lower == 'confirmed') return 'Confirmed';
    if (lower == 'completed') return 'Completed';
    if (lower == 'pending') return 'Pending';
    if (lower == 'cancelled' || lower == 'canceled') return 'Cancelled';
    if (lower == 'scheduled') return 'Confirmed';
    return status;
  }

  Color _getStatusColor(String status) {
    final normalized = _normalizeStatus(status);
    switch (normalized) {
      case 'Confirmed':
      case 'Completed':
        return AppColors.success;
      case 'Pending':
        return AppColors.warning;
      case 'Cancelled':
        return AppColors.error;
      default:
        return AppColors.primaryBlue;
    }
  }

  Future<void> _cancelAppointment(AppointmentData appointment) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Cancel Appointment',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this appointment? It will be moved to your history.',
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.gray700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final response = await ApiService().request(
          method: 'PUT',
          endpoint: '/appointments/${appointment.id}/cancel',
        );
        if (response['success'] == true) {
          if (mounted) {
            try {
              final notifId = DateTime.now().millisecondsSinceEpoch % 1000000;
              await NotificationService.showNotification(
                id: notifId,
                title: 'Appointment Cancelled ❌',
                body: 'Your appointment with ${appointment.doctorName} has been cancelled.',
                type: 'appointment',
                saveToHistory: true,
              );

              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            } catch (e) {
              debugPrint('Failed to save cancellation notification: $e');
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Appointment cancelled and moved to history'),
                backgroundColor: AppColors.success,
              ),
            );
            _loadAppointments();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['error']?.toString() ?? 'Failed to cancel appointment'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _copyRoomId(String roomId) {
    final cleanId = roomId.trim();
    final formattedRoom = cleanId.startsWith('SMH-') ? cleanId : 'SMH-$cleanId';
    final link = 'https://meet.jit.si/$formattedRoom';

    FlutterClipboard.copy(link).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting link copied to clipboard!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const LoadingWidget()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Appointments',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isListView ? Icons.calendar_month : Icons.list,
                              color: isDark ? Colors.white : AppColors.primaryBlue,
                            ),
                            onPressed: () => setState(() => _isListView = !_isListView),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: isDark ? Colors.white : AppColors.primaryBlue,
                            ),
                            onPressed: _isLoading ? null : _loadAppointments,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Upcoming',
                        _upcomingAppointments.length.toString(),
                        AppColors.primaryBlue,
                        isDark,
                      ),
                      _buildStatCard(
                        'History',
                        _pastAppointments.length.toString(),
                        AppColors.success,
                        isDark,
                      ),
                      _buildStatCard(
                        'Pending',
                        _upcomingAppointments
                            .where((apt) => _normalizeStatus(apt.status) == 'Pending')
                            .length
                            .toString(),
                        AppColors.warning,
                        isDark,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _isListView ? _buildListView(isDark) : _buildCalendarView(isDark),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BookAppointmentScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryBlue,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.gray700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildListView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_upcomingAppointments.isNotEmpty) ...[
          _buildSectionHeader('Upcoming Appointments', Icons.event_available, isDark),
          ..._upcomingAppointments.map((apt) => _buildAppointmentCard(apt, isDark)),
          const SizedBox(height: 24),
        ],
        if (_pastAppointments.isNotEmpty) ...[
          _buildSectionHeader('Appointments History', Icons.history, isDark),
          ..._pastAppointments.map((apt) => _buildAppointmentCard(apt, isDark)),
        ],
        if (_upcomingAppointments.isEmpty && _pastAppointments.isEmpty)
          _buildEmptyState(isDark),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      height: 400,
      alignment: Alignment.center,
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
              Icons.calendar_today_outlined,
              size: 50,
              color: isDark ? Colors.grey.shade600 : AppColors.gray300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Appointments Yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.gray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book your first appointment to get started',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.gray700,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BookAppointmentScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Book Appointment'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(bool isDark) {
    return SfCalendar(
      view: CalendarView.month,
      dataSource: _AppointmentDataSource(_calendarAppointments),
      backgroundColor: Colors.transparent,
      todayHighlightColor: AppColors.primaryBlue,
      cellBorderColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      monthViewSettings: const MonthViewSettings(
        appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentData appointment, bool isDark) {
    final normalizedStatus = _normalizeStatus(appointment.status);
    final Color statusColor = _getStatusColor(normalizedStatus);
    final bool isTelemedicine = appointment.type.toLowerCase() == 'telemedicine';
    final bool hasRoomId = appointment.telemedicineRoomId != null && appointment.telemedicineRoomId!.isNotEmpty;
    final bool isCancellable = normalizedStatus == 'Pending' || normalizedStatus == 'Confirmed';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAppointmentDetails(appointment),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _buildDoctorAvatar(appointment),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.doctorName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appointment.specialty,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.gray700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: isDark ? Colors.white60 : AppColors.gray700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(appointment.dateTime),
                            style: TextStyle(
                              color: isDark ? Colors.white60 : AppColors.gray700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: isDark ? Colors.white60 : AppColors.gray700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('hh:mm a').format(appointment.dateTime),
                            style: TextStyle(
                              color: isDark ? Colors.white60 : AppColors.gray700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (isTelemedicine && hasRoomId) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _copyRoomId(appointment.telemedicineRoomId!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.meeting_room,
                                  size: 12,
                                  color: AppColors.primaryBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Room: meet.jit.si/${appointment.telemedicineRoomId}',
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.copy,
                                  size: 12,
                                  color: AppColors.primaryBlue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        normalizedStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isTelemedicine && hasRoomId && normalizedStatus == 'Confirmed') ...[
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => VCallHelper.openRoom(context, appointment.telemedicineRoomId!),
                          icon: const Icon(Icons.video_call, size: 14, color: Colors.white),
                          label: const Text('Join', style: TextStyle(fontSize: 11, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (isCancellable)
                      SizedBox(
                        width: 80,
                        height: 30,
                        child: OutlinedButton(
                          onPressed: () => _cancelAppointment(appointment),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildDoctorAvatar(AppointmentData appointment) {
    final String? imageUrl = appointment.doctorImage;
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('data:image')) {
        try {
          final base64String = imageUrl.split(',').last;
          final bytes = base64.decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(appointment),
          );
        } catch (e) {
          return _buildInitialsAvatar(appointment);
        }
      }
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildInitialsAvatar(appointment),
        errorWidget: (context, url, error) => _buildInitialsAvatar(appointment),
      );
    }
    return _buildInitialsAvatar(appointment);
  }

  Widget _buildInitialsAvatar(AppointmentData appointment) {
    final String initials = appointment.doctorName
        .replaceAll('Dr. ', '')
        .split(' ')
        .map((name) => name.isNotEmpty ? name[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    
    final normalizedStatus = _normalizeStatus(appointment.status);
    final Color statusColor = _getStatusColor(normalizedStatus);
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ),
    );
  }

  void _showAppointmentDetails(AppointmentData appointment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalizedStatus = _normalizeStatus(appointment.status);
    final bool isTelemedicine = appointment.type.toLowerCase() == 'telemedicine';
    final bool hasRoomId = appointment.telemedicineRoomId != null && appointment.telemedicineRoomId!.isNotEmpty;
    final bool isCancellable = normalizedStatus == 'Pending' || normalizedStatus == 'Confirmed';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _buildDoctorAvatar(appointment),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appointment.doctorName,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Specialty', appointment.specialty, isDark),
            _buildDetailRow('Date', DateFormat('MMMM dd, yyyy').format(appointment.dateTime), isDark),
            _buildDetailRow('Time', DateFormat('hh:mm a').format(appointment.dateTime), isDark),
            _buildDetailRow('Type', appointment.type, isDark),
            _buildDetailRow('Hospital', appointment.hospital, isDark),
            _buildDetailRow('Status', normalizedStatus, isDark),
            if (isTelemedicine && hasRoomId) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Telemedicine Room',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'meet.jit.si/${appointment.telemedicineRoomId}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: AppColors.primaryBlue),
                          onPressed: () => _copyRoomId(appointment.telemedicineRoomId!),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
          if (isCancellable)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelAppointment(appointment);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancel Appointment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          if (isTelemedicine && hasRoomId && normalizedStatus == 'Confirmed')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                VCallHelper.openRoom(context, appointment.telemedicineRoomId!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Join Video Call',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppointmentData {
  final String id;
  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String status;
  final String type;
  final String hospital;
  final String? telemedicineRoomId;
  final String? doctorImage;

  AppointmentData({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.status,
    required this.type,
    required this.hospital,
    this.telemedicineRoomId,
    this.doctorImage,
  });

  factory AppointmentData.fromJson(Map<String, dynamic> json, Map<String, String> doctorImages) {
    final doctorId = json['doctor_id']?.toString();
    final image = doctorId != null ? doctorImages[doctorId] : null;
    
    String status = json['status'] ?? 'scheduled';
    
    return AppointmentData(
      id: json['id']?.toString() ?? '',
      doctorName: json['doctor_name'] ?? 
                  'Dr. ${json['doctor_first_name'] ?? ''} ${json['doctor_last_name'] ?? ''}'.trim(),
      specialty: json['doctor_specialty'] ?? json['specialty'] ?? 'General Practice',
      dateTime: json['appointment_date'] != null
          ? DateTime.parse(json['appointment_date'])
          : DateTime.now(),
      status: status,
      type: json['consultation_type'] ?? 'in_person',
      hospital: json['doctor_hospital'] ?? json['hospital'] ?? 'Medical Center',
      telemedicineRoomId: json['telemedicine_room_id'],
      doctorImage: image,
    );
  }
}

class _AppointmentDataSource extends CalendarDataSource {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}