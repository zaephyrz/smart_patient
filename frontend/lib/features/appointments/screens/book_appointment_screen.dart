import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:clipboard/clipboard.dart';
import '../../../config/constants.dart';
import '../../../config/theme.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/app_top_bar.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptomsController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingDoctors = true;
  bool _isTelemedicine = false;
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  String? _selectedDate;
  String? _selectedTime;
  String? _selectedConsultationType = 'in_person';
  String? _errorMessage;
  String? _generatedRoomId;

  List<Map<String, dynamic>> _doctors = [];
  final List<String> _availableTimes = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', 
    '11:00 AM', '11:30 AM', '02:00 PM', '02:30 PM',
    '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM',
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoadingDoctors = true;
      _errorMessage = null;
    });

    try {
      final token = await StorageService().getAuthToken();
      if (token == null) {
        setState(() {
          _isLoadingDoctors = false;
          _errorMessage = 'Please login to book an appointment';
        });
        return;
      }

      final result = await ApiService().request(
        method: 'GET',
        endpoint: '/doctors',
      );

      if (result['success'] == true) {
        List<dynamic> doctorsList = [];
        
        if (result['doctors'] != null) {
          doctorsList = result['doctors'] as List;
        } else if (result['data'] != null) {
          final data = result['data'];
          if (data is List) {
            doctorsList = data;
          } else if (data is Map && data['doctors'] != null) {
            doctorsList = data['doctors'] as List;
          }
        }

        if (doctorsList.isEmpty) {
          setState(() {
            _doctors = [];
            _isLoadingDoctors = false;
            _errorMessage = 'No doctors available at the moment';
          });
          return;
        }

        final processedDoctors = doctorsList.map((doctor) {
          return {
            'id': doctor['id']?.toString() ?? '',
            'first_name': doctor['first_name'] ?? '',
            'last_name': doctor['last_name'] ?? '',
            'full_name': doctor['full_name'] ?? 
                'Dr. ${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'.trim(),
            'specialty': doctor['specialty'] ?? 'General Practice',
            'hospital_affiliation': doctor['hospital_affiliation'] ?? 
                doctor['hospital'] ?? 'Medical Center',
            'consultation_fee': doctor['consultation_fee'] ?? 0.0,
            'rating': doctor['rating'] ?? 0.0,
            'profile_image': doctor['profile_image'] ?? '',
          };
        }).toList();

        setState(() {
          _doctors = List<Map<String, dynamic>>.from(processedDoctors);
          _isLoadingDoctors = false;
        });
      } else {
        setState(() {
          _doctors = [];
          _isLoadingDoctors = false;
          _errorMessage = result['error'] ?? 'Failed to load doctors';
        });
      }
    } catch (e) {
      debugPrint('Error loading doctors: $e');
      setState(() {
        _doctors = [];
        _isLoadingDoctors = false;
        _errorMessage = 'Network error: ${e.toString()}';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _bookAppointment() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDoctorId == null) {
        setState(() => _errorMessage = 'Please select a doctor');
        return;
      }
      if (_selectedDate == null) {
        setState(() => _errorMessage = 'Please select a date');
        return;
      }
      if (_selectedTime == null) {
        setState(() => _errorMessage = 'Please select a time');
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _generatedRoomId = null;
      });

      try {
        final token = await StorageService().getAuthToken();
        if (token == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Please login to book an appointment';
          });
          return;
        }

        final timeFormat = DateFormat('hh:mm a');
        final parsedTime = timeFormat.parse(_selectedTime!);
        final time24Hour = DateFormat('HH:mm:ss').format(parsedTime);
        final dateTimeString = '$_selectedDate $time24Hour';
        
        final appointmentData = {
          'doctor_id': _selectedDoctorId,
          'appointment_date': dateTimeString,
          'symptoms': _symptomsController.text.trim(),
          'notes': _notesController.text.trim(),
          'consultation_type': _selectedConsultationType,
          'is_telemedicine': _isTelemedicine,
        };

        final result = await ApiService().request(
          method: 'POST',
          endpoint: '/appointments',
          data: appointmentData,
        );

        setState(() => _isLoading = false);

        if (result['success'] == true && mounted) {
          String? roomId;
          if (result['telemedicine_room_id'] != null) {
            String rawId = result['telemedicine_room_id'].toString();
            roomId = rawId.startsWith('SMH-') ? rawId : 'SMH-$rawId';
            setState(() {
              _generatedRoomId = roomId;
            });
          } else if (_isTelemedicine) {
            roomId = 'SMH-${DateTime.now().millisecondsSinceEpoch % 100000}';
            setState(() {
              _generatedRoomId = roomId;
            });
          }
          
          Navigator.pop(context, true);
          
          String message = 'Appointment booked successfully!';
          if (_isTelemedicine && roomId != null) {
            message = 'Appointment booked successfully!\nRoom: meet.jit.si/$roomId';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          _showAppointmentBookedPopup(context, message);

          try {
            final notifId = DateTime.now().millisecondsSinceEpoch % 1000000;
            final notifTitle = 'Appointment Confirmed 🏥';
            final notifBody = _isTelemedicine 
                ? 'Your telemedicine appointment with ${_selectedDoctorName ?? "doctor"} is confirmed. Room: meet.jit.si/$roomId'
                : 'Your in-person appointment with ${_selectedDoctorName ?? "doctor"} has been booked for $_selectedDate at $_selectedTime.';

            await NotificationService.showNotification(
              id: notifId,
              title: notifTitle,
              body: notifBody,
              type: _isTelemedicine ? 'telemedicine' : 'appointment',
              saveToHistory: true,
            );

            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadNotificationCountProvider);
          } catch (e) {
            debugPrint('Failed to show local notification: $e');
          }
        } else {
          setState(() => _errorMessage = result['error']?.toString() ?? 'Failed to book appointment');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred: ${e.toString()}';
        });
      }
    }
  }

  void _showAppointmentBookedPopup(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            Text(
              '✅ Appointment Booked!',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.success,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.gray700,
              ),
            ),
            const SizedBox(height: 12),
            if (_isTelemedicine && _generatedRoomId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.meeting_room, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Room: meet.jit.si/$_generatedRoomId',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: AppColors.primaryBlue),
                      onPressed: () {
                        FlutterClipboard.copy('https://meet.jit.si/$_generatedRoomId').then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied to clipboard!'),
                              backgroundColor: AppColors.success,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        });
                      },
                      tooltip: 'Copy Link',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'You can find your meeting room and join directly from your Appointments screen.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : AppColors.gray700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Done',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorAvatar(Map<String, dynamic> doctor, bool isSelected, bool isDark) {
    final String? imageUrl = doctor['profile_image'];
    final String fullName = doctor['full_name'] ?? 'Dr. Unknown';
    final Color borderColor = isSelected ? AppColors.primaryBlue : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);
    
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryBlue.withValues(alpha: 0.7),
                ],
              )
            : null,
      ),
      child: ClipOval(
        child: _buildDoctorImage(imageUrl, fullName, isDark),
      ),
    );
  }

  Widget _buildDoctorImage(String? imageUrl, String fullName, bool isDark) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('data:image')) {
        try {
          final base64String = imageUrl.split(',').last;
          final bytes = base64.decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(fullName, isDark),
          );
        } catch (e) {
          return _buildInitialsAvatar(fullName, isDark);
        }
      }
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildInitialsAvatar(fullName, isDark),
        errorWidget: (context, url, error) => _buildInitialsAvatar(fullName, isDark),
      );
    }
    return _buildInitialsAvatar(fullName, isDark);
  }

  Widget _buildInitialsAvatar(String fullName, bool isDark) {
    final String name = fullName.replaceAll('Dr. ', '');
    final String initials = name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'D',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: const AppTopBar(title: 'Book Appointment', showBackButton: true),
      body: _isLoadingDoctors
          ? const LoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.primaryGreen.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Book Appointment',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Schedule a consultation with a doctor',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader('Consultation Type', isDark),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Text(
                                'In-Person',
                                style: TextStyle(
                                  color: _selectedConsultationType == 'in_person' 
                                      ? Colors.white 
                                      : (isDark ? Colors.white70 : AppColors.black),
                                ),
                              ),
                              selected: _selectedConsultationType == 'in_person',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedConsultationType = 'in_person';
                                  _isTelemedicine = false;
                                });
                              },
                              selectedColor: AppColors.primaryBlue,
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Text(
                                'Telemedicine',
                                style: TextStyle(
                                  color: _selectedConsultationType == 'telemedicine' 
                                      ? Colors.white 
                                      : (isDark ? Colors.white70 : AppColors.black),
                                ),
                              ),
                              selected: _selectedConsultationType == 'telemedicine',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedConsultationType = 'telemedicine';
                                  _isTelemedicine = true;
                                });
                              },
                              selectedColor: AppColors.primaryBlue,
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader('Select Doctor', isDark),
                    if (_errorMessage != null && _doctors.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_doctors.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_search, 
                                size: 48, 
                                color: isDark ? Colors.white60 : Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No doctors available',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try again later or contact support',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._doctors.map((doctor) {
                        final doctorId = doctor['id']?.toString();
                        final isSelected = _selectedDoctorId == doctorId;
                        final doctorName = doctor['full_name'] ?? 
                                         '${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'.trim();
                        final specialty = doctor['specialty'] ?? 'General Practice';
                        final hospital = doctor['hospital_affiliation'] ?? 'Medical Center';
                        final fee = doctor['consultation_fee'] ?? 0.0;
                        final rating = doctor['rating'] ?? 0.0;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                                : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: AppColors.primaryBlue, width: 2)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  _selectedDoctorId = doctorId;
                                  _selectedDoctorName = doctorName;
                                  _errorMessage = null;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    _buildDoctorAvatar(doctor, isSelected, isDark),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doctorName.isNotEmpty ? doctorName : 'Dr. Unknown',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isSelected 
                                                  ? AppColors.primaryBlue 
                                                  : (isDark ? Colors.white : AppColors.black),
                                            ),
                                          ),
                                          Text(
                                            specialty,
                                            style: TextStyle(
                                              color: isSelected 
                                                  ? AppColors.primaryBlue 
                                                  : (isDark ? Colors.white70 : AppColors.gray700),
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            hospital,
                                            style: TextStyle(
                                              color: isDark ? Colors.white60 : AppColors.gray700,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                '\$${fee.toStringAsFixed(2)} consultation fee',
                                                style: const TextStyle(
                                                  color: AppColors.primaryBlue,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (rating > 0) ...[
                                                const SizedBox(width: 12),
                                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  rating.toStringAsFixed(1),
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white60 : AppColors.gray700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.primaryBlue,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    _buildSectionHeader('Select Date', isDark),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _selectDate(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isDark ? Colors.grey.shade700 : AppColors.gray300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: _selectedDate != null ? AppColors.primaryBlue : (isDark ? Colors.white60 : AppColors.gray700),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate != null
                                  ? DateFormat('MMMM dd, yyyy').format(
                                      DateTime.parse(_selectedDate!),
                                    )
                                  : 'Select Date',
                              style: TextStyle(
                                color: _selectedDate != null
                                    ? AppColors.primaryBlue
                                    : (isDark ? Colors.white60 : AppColors.gray700),
                                fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_selectedDate != null) ...[
                      _buildSectionHeader('Select Time', isDark),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableTimes.map((time) {
                            final isSelected = _selectedTime == time;
                            return FilterChip(
                              label: Text(
                                time,
                                style: TextStyle(
                                  color: isSelected 
                                      ? Colors.white 
                                      : (isDark ? Colors.white70 : AppColors.black),
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTime = selected ? time : null;
                                });
                              },
                              selectedColor: AppColors.primaryBlue,
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    _buildSectionHeader('Symptoms (Optional)', isDark),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _symptomsController,
                        maxLines: 3,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Describe your symptoms...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white60 : AppColors.gray700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Additional notes...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white60 : AppColors.gray700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    if (_errorMessage != null && _doctors.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                              const Icon(Icons.error_outline, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_selectedDoctorName != null)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: AppColors.primaryBlue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Doctor',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : AppColors.gray700,
                                    ),
                                  ),
                                  Text(
                                    _selectedDoctorName!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppColors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _bookAppointment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          disabledBackgroundColor: isDark 
                              ? Colors.grey.shade800 
                              : Colors.grey.shade300,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Book Appointment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.primaryBlue,
        ),
      ),
    );
  }
}