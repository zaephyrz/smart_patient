import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../../../config/constants.dart';
import '../../../config/environment.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../auth/screens/login_screen.dart';

class MedicalRecordsScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  
  const MedicalRecordsScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  ConsumerState<MedicalRecordsScreen> createState() =>
      _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends ConsumerState<MedicalRecordsScreen> {
  bool _isLoading = false;
  bool _isDownloading = false;
  List<MedicalRecord> _records = [];
  final List<String> _filterTypes = ['All', 'Prescription', 'Lab Report', 'X-Ray', 'Receipt', 'Immunization', 'Other'];
  String _selectedFilter = 'All';
  late final ApiService _apiService;
  String? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _loadMedicalRecords();
  }

  Future<void> _loadMedicalRecords() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final storageService = StorageService();
      final token = await storageService.getAuthToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to view your medical records'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await _apiService.getMedicalRecords(token: token);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        List<dynamic> recordsData = [];
        
        if (data is List) {
          recordsData = data;
        } else if (data is Map && data['medical_records'] != null) {
          recordsData = data['medical_records'] as List;
        } else if (data is Map && data['data'] != null) {
          final nestedData = data['data'];
          if (nestedData is List) {
            recordsData = nestedData;
          } else if (nestedData is Map && nestedData['medical_records'] != null) {
            recordsData = nestedData['medical_records'] as List;
          }
        }
        
        if (recordsData.isNotEmpty) {
          _records = recordsData.map((json) => MedicalRecord.fromJson(json)).toList();
        } else {
          _records = [];
        }
      } else {
        _records = [];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to load records'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      _records = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading records: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<MedicalRecord> get _filteredRecords {
    if (_selectedFilter == 'All') {
      return _records;
    }
    return _records.where((record) => record.type == _selectedFilter).toList();
  }

  bool _isDesktopPlatform() {
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  Future<bool> _checkAndRequestPermission() async {
    if (_isDesktopPlatform() || kIsWeb) {
      return true;
    }

    try {
      final status = await Permission.storage.status;
      if (status.isGranted) return true;
      
      final result = await Permission.storage.request();
      if (result.isGranted) return true;
      
      if (result.isPermanentlyDenied && mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1E1E1E) 
                : Colors.white,
            title: Text(
              'Storage Permission Required',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : null,
              ),
            ),
            content: Text(
              'Storage permission is permanently denied. Please enable it in settings to download files.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white70 
                    : null,
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
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white70 
                        : null,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Open Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        );
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  Future<void> _downloadRecord(MedicalRecord record) async {
    if (!mounted) return;

    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to download files'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 'Starting download...';
    });

    try {
      final storageService = StorageService();
      final token = await storageService.getAuthToken();
      if (token == null || token.trim().isEmpty) {
        throw Exception('Authentication session expired. Please log in again.');
      }

      // Get downloads directory
      final downloadsDir = await storageService.getDownloadsDirectory();
      final directory = Directory(downloadsDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create filename
      final cleanTitle = record.title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final String fileName = '${cleanTitle}_${record.id}.pdf';
      final String filePath = '$downloadsDir/$fileName';

      setState(() => _downloadProgress = 'Downloading file...');

      // Build URL - use the backend URL directly
      final String baseUrl = Environment.backendUrl;
      final String cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final String downloadUrl = '$cleanBaseUrl/api/v1/medical-records/${record.id}/download';

      debugPrint('Download URL: $downloadUrl');  // Debug print

      // Create HTTP client with headers
      final client = http.Client();
      try {
        final response = await client.get(
          Uri.parse(downloadUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/pdf',
          },
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          // Write the file
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (await file.exists() && await file.length() > 0) {
            setState(() => _downloadProgress = 'Opening file...');
            
            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${record.title} downloaded successfully'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
            
            // Open the file
            final openResult = await OpenFilex.open(filePath);
            if (openResult.type == ResultType.error && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error opening file: ${openResult.message}'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          } else {
            throw Exception('Downloaded file is empty or corrupted');
          }
        } else if (response.statusCode == 401) {
          if (mounted) {
            _showSessionExpiredDialog();
          }
          return;
        } else {
          final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
          throw Exception('Server error: ${response.statusCode} - $errorBody');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Download error: $e');  // Debug print
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('404')) {
          errorMessage = 'File not found on server.';
        } else if (errorMessage.contains('401')) {
          errorMessage = 'Authentication expired. Please login again.';
          _showSessionExpiredDialog();
        } else if (errorMessage.contains('timeout')) {
          errorMessage = 'Connection timeout. Please try again.';
        } else if (errorMessage.contains('Connection refused')) {
          errorMessage = 'Could not connect to server. Make sure the backend is running.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $errorMessage'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  void _showSessionExpiredDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.lock_clock, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text(
              'Session Expired',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.black,
              ),
            ),
          ],
        ),
        content: Text(
          'Your session could not be verified. Please log in again to download this record.',
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.gray700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : AppColors.gray700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSessionExpired();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log In Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSessionExpired() async {
    await StorageService().clearAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                if (widget.showBackButton)
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : AppColors.black,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                else
                  const SizedBox(width: 48),
                
                Expanded(
                  child: Center(
                    child: Text(
                      'Medical Records',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: isDark ? Colors.white : AppColors.primaryBlue,
                  ),
                  onPressed: _isLoading ? null : _loadMedicalRecords,
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterTypes.map((type) {
                  final isSelected = _selectedFilter == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        type,
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white70 : AppColors.black),
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedFilter = type);
                      },
                      selectedColor: AppColors.primaryBlue,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected 
                            ? Colors.white 
                            : (isDark ? Colors.white70 : AppColors.black),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Total Records',
                  _records.length.toString(),
                  Icons.folder_open,
                  AppColors.primaryBlue,
                  isDark,
                ),
                _buildStatCard(
                  'Total Size',
                  _isDownloading ? 'Downloading...' : '${_records.length} files',
                  Icons.storage,
                  AppColors.primaryGreen,
                  isDark,
                ),
                _buildStatCard(
                  'Last Updated',
                  _records.isNotEmpty 
                      ? DateFormat('MMM dd').format(_records.first.date)
                      : 'N/A',
                  Icons.update,
                  AppColors.accentBlue,
                  isDark,
                ),
              ],
            ),
          ),

          if (_isDownloading && _downloadProgress != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _downloadProgress!,
                    style: TextStyle(
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  )
                : _filteredRecords.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = _filteredRecords[index];
                          return _buildRecordCard(record, isDark);
                        },
                      ),
          ),
        ],
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
              Icons.folder_open_outlined,
              size: 50,
              color: isDark ? Colors.grey.shade600 : AppColors.gray300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Medical Records',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.gray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Your medical records will appear here'
                : 'No ${_selectedFilter.toLowerCase()} records found',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.gray700,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadMedicalRecords,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Refresh', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
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
            child: Icon(icon, color: color, size: 22),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.gray700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(MedicalRecord record, bool isDark) {
    final Color recordColor = _getRecordColor(record.type);
    
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
          onTap: () => _showRecordDetails(record),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: recordColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          _getRecordIcon(record.type),
                          color: recordColor,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: recordColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  record.type,
                                  style: TextStyle(
                                    color: recordColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today,
                                size: 10,
                                color: isDark ? Colors.white60 : AppColors.gray700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM dd, yyyy').format(record.date),
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : AppColors.gray700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          if (record.department != 'N/A') ...[
                            const SizedBox(height: 2),
                            Text(
                              'Dept: ${record.department}',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : AppColors.gray700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          record.size,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : AppColors.gray700,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        IconButton(
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.download,
                                  size: 18,
                                  color: isDark ? Colors.white : AppColors.primaryBlue,
                                ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _isDownloading ? null : () => _downloadRecord(record),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  record.description,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.gray700,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: isDark ? Colors.white60 : AppColors.gray700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.doctor,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : AppColors.gray700,
                        fontSize: 11,
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

  void _showRecordDetails(MedicalRecord record) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          record.title,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Type', record.type, isDark),
              _buildDetailRow('Date', DateFormat('MMMM dd, yyyy').format(record.date), isDark),
              _buildDetailRow('Doctor', record.doctor, isDark),
              _buildDetailRow('Size', record.size, isDark),
              if (record.department != 'N/A') _buildDetailRow('Department', record.department, isDark),
              if (record.diagnosisCode != 'N/A') _buildDetailRow('Diagnosis Code', record.diagnosisCode, isDark),
              if (record.icd10Code != 'N/A') _buildDetailRow('ICD-10 Code', record.icd10Code, isDark),
              if (record.labResults != 'N/A') _buildDetailRow('Lab Results', record.labResults, isDark),
              if (record.vitals != 'N/A') _buildDetailRow('Vitals', record.vitals, isDark),
              if (record.medications != 'N/A') _buildDetailRow('Medications', record.medications, isDark),
              if (record.allergies != 'N/A') _buildDetailRow('Allergies', record.allergies, isDark),
              const SizedBox(height: 12),
              Text(
                'Description:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record.description,
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.gray700,
                ),
              ),
              if (record.notes != 'N/A' && record.notes != record.description) ...[
                const SizedBox(height: 12),
                Text(
                  'Additional Notes:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.notes,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.gray700,
                  ),
                ),
              ],
            ],
          ),
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
          ElevatedButton.icon(
            onPressed: _isDownloading ? null : () {
              Navigator.pop(context);
              _downloadRecord(record);
            },
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 20, color: Colors.white),
            label: Text(_isDownloading ? 'Downloading...' : 'Download', style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppColors.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRecordColor(String type) {
    switch (type.toLowerCase()) {
      case 'prescription':
        return AppColors.primaryBlue;
      case 'lab report':
        return AppColors.primaryGreen;
      case 'x-ray':
        return AppColors.accentBlue;
      case 'receipt':
        return Colors.purple;
      case 'immunization':
        return AppColors.accentGreen;
      default:
        return AppColors.gray700;
    }
  }

  IconData _getRecordIcon(String type) {
    switch (type.toLowerCase()) {
      case 'prescription':
        return Icons.medication;
      case 'lab report':
        return Icons.science;
      case 'x-ray':
        return Icons.medical_services;
      case 'receipt':
        return Icons.receipt_long;
      case 'immunization':
        return Icons.vaccines;
      default:
        return Icons.description;
    }
  }
}

class MedicalRecord {
  final String id;
  final String title;
  final String type;
  final DateTime date;
  final String size;
  final String doctor;
  final String description;
  final String downloadUrl;
  final String department;
  final String attendingPhysician;
  final String diagnosisCode;
  final String icd10Code;
  final String labResults;
  final String vitals;
  final String medications;
  final String allergies;
  final String notes;

  MedicalRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.size,
    required this.doctor,
    required this.description,
    required this.downloadUrl,
    this.department = 'N/A',
    this.attendingPhysician = 'N/A',
    this.diagnosisCode = 'N/A',
    this.icd10Code = 'N/A',
    this.labResults = 'N/A',
    this.vitals = 'N/A',
    this.medications = 'N/A',
    this.allergies = 'N/A',
    this.notes = 'N/A',
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    String doctorName = 'Unknown Doctor';
    
    if (json['attending_physician'] != null && json['attending_physician'].toString().isNotEmpty) {
      doctorName = json['attending_physician'].toString();
    } else if (json['doctor'] != null && json['doctor'].toString().isNotEmpty) {
      doctorName = json['doctor'].toString();
    } else if (json['title'] != null) {
      final title = json['title'].toString();
      final drMatch = RegExp(r'Dr\.\s+[A-Za-z]+').firstMatch(title);
      if (drMatch != null) {
        doctorName = drMatch.group(0) ?? 'Unknown Doctor';
      }
    }

    String fileSize = 'Unknown';
    if (json['file_size'] != null) {
      final sizeValue = json['file_size'];
      if (sizeValue is int || sizeValue is double) {
        final sizeInBytes = (sizeValue as num).toDouble();
        if (sizeInBytes > 0) {
          fileSize = '${(sizeInBytes / 1048576).toStringAsFixed(1)} MB';
        }
      } else if (sizeValue is String) {
        fileSize = sizeValue;
        if (!fileSize.contains('MB') && !fileSize.contains('KB')) {
          try {
            final numValue = double.tryParse(sizeValue);
            if (numValue != null && numValue > 0) {
              fileSize = '${(numValue / 1048576).toStringAsFixed(1)} MB';
            }
          } catch (_) {}
        }
      }
    } else if (json['size'] != null) {
      fileSize = json['size'].toString();
    }

    return MedicalRecord(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled Record',
      type: json['record_type'] ?? json['type'] ?? 'Other',
      date: json['record_date'] != null
          ? DateTime.parse(json['record_date'])
          : json['date'] != null
              ? DateTime.parse(json['date'])
              : DateTime.now(),
      size: fileSize,
      doctor: doctorName,
      description: json['description'] ?? 'No description available',
      downloadUrl: json['download_url'] ?? '',
      department: json['department'] ?? 'N/A',
      attendingPhysician: json['attending_physician'] ?? 'N/A',
      diagnosisCode: json['diagnosis_code'] ?? 'N/A',
      icd10Code: json['icd10_code'] ?? 'N/A',
      labResults: json['lab_results'] ?? 'N/A',
      vitals: json['vitals'] ?? 'N/A',
      medications: json['medications'] ?? 'N/A',
      allergies: json['allergies'] ?? 'N/A',
      notes: json['notes'] ?? 'N/A',
    );
  }
}