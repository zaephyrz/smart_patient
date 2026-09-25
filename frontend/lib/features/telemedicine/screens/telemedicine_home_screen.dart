import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:clipboard/clipboard.dart';
import '../../../core/services/v_call_helper.dart';
import '../../../config/constants.dart';
import '../../../shared/widgets/app_top_bar.dart';

class TelemedicineHomeScreen extends ConsumerStatefulWidget {
  const TelemedicineHomeScreen({super.key});

  @override
  ConsumerState<TelemedicineHomeScreen> createState() => _TelemedicineHomeScreenState();
}

class _TelemedicineHomeScreenState extends ConsumerState<TelemedicineHomeScreen> {
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _launchRoom(String rawRoomId) {
    final cleanId = rawRoomId.trim();
    if (cleanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Room ID'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Format strictly as meet.jit.si/SMH-91622
    final formattedRoom = cleanId.startsWith('SMH-') ? cleanId : 'SMH-$cleanId';
    VCallHelper.openRoom(context, formattedRoom);
  }

  void _copyRoom(String rawRoomId) {
    final cleanId = rawRoomId.trim();
    if (cleanId.isEmpty) return;
    final formattedRoom = cleanId.startsWith('SMH-') ? cleanId : 'SMH-$cleanId';
    final link = 'https://meet.jit.si/$formattedRoom';
    
    FlutterClipboard.copy(link).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting link copied to clipboard!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _shareRoom(String rawRoomId) {
    final cleanId = rawRoomId.trim();
    if (cleanId.isEmpty) return;
    final formattedRoom = cleanId.startsWith('SMH-') ? cleanId : 'SMH-$cleanId';
    final link = 'https://meet.jit.si/$formattedRoom';

    Share.share(
      'Join my telemedicine consultation:\n'
      'Room: $formattedRoom\n'
      'Link: $link\n\n'
      'Click the link above to join the video consultation.',
      subject: 'Smart Medical Hub - Telemedicine Invite',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: const AppTopBar(title: 'Telemedicine', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.video_call,
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
                          'Virtual Consultations',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Connect with your doctor securely via browser video call',
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

            const SizedBox(height: 20),

            Container(
              decoration: _fieldDecoration(context, isDark),
              child: TextFormField(
                controller: _roomController,
                style: TextStyle(color: isDark ? Colors.white : AppColors.black),
                decoration: InputDecoration(
                  labelText: 'Enter Room ID',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.gray700),
                  hintText: 'e.g., SMH-91622',
                  hintStyle: TextStyle(color: isDark ? Colors.white60 : AppColors.gray700),
                  helperText: 'Format: meet.jit.si/SMH-91622',
                  helperStyle: TextStyle(color: isDark ? Colors.white60 : AppColors.gray700),
                  prefixIcon: const Icon(Icons.meeting_room, color: AppColors.primaryBlue),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              decoration: _fieldDecoration(context, isDark),
              child: TextFormField(
                controller: _nameController,
                style: TextStyle(color: isDark ? Colors.white : AppColors.black),
                decoration: InputDecoration(
                  labelText: 'Your Name (Optional)',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.gray700),
                  hintText: 'John Doe',
                  hintStyle: TextStyle(color: isDark ? Colors.white60 : AppColors.gray700),
                  prefixIcon: const Icon(Icons.person, color: AppColors.primaryBlue),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _launchRoom(_roomController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Join Call in Browser',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyRoom(_roomController.text.isEmpty ? 'SMH-91622' : _roomController.text),
                    icon: const Icon(Icons.copy, color: AppColors.primaryBlue),
                    label: const Text('Copy Link', style: TextStyle(color: AppColors.primaryBlue)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareRoom(_roomController.text.isEmpty ? 'SMH-91622' : _roomController.text),
                    icon: const Icon(Icons.share, color: AppColors.primaryGreen),
                    label: const Text('Share Link', style: TextStyle(color: AppColors.primaryGreen)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchRoom('SMH-DEMO123'),
                icon: const Icon(Icons.video_library, color: AppColors.primaryBlue),
                label: const Text('Join Demo Call (SMH-DEMO123)', style: TextStyle(color: AppColors.primaryBlue)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _fieldDecoration(BuildContext context, bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}