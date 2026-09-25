import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/constants.dart';

class AvatarSelector extends StatefulWidget {
  final String? currentAvatar;
  final Function(String) onAvatarSelected;

  const AvatarSelector({
    super.key,
    this.currentAvatar,
    required this.onAvatarSelected,
  });

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  String? _selectedAvatar;
  String? _selectedAvatarPath;
  bool _isLoading = false;

  static const List<Color> initialColors = [
    Color(0xFFE57373),
    Color(0xFFF06292),
    Color(0xFFBA68C8),
    Color(0xFF9575CD),
    Color(0xFF7986CB),
    Color(0xFF64B5F6),
    Color(0xFF4FC3F7),
    Color(0xFF4DD0E1),
    Color(0xFF81C784),
    Color(0xFFAED581),
    Color(0xFFFFD54F),
    Color(0xFFFFB74D),
    Color(0xFFFF8A65),
    Color(0xFFA1887F),
    Color(0xFF90A4AE),
  ];

  static const List<String> sampleInitials = [
    'JD', 'AB', 'CD', 'EF', 'GH', 'IJ', 'KL', 'MN',
    'OP', 'QR', 'ST', 'UV', 'WX', 'YZ', 'SM', 'JH',
  ];

  @override
  void initState() {
    super.initState();
    // Check if currentAvatar is a file path or initials
    final avatar = widget.currentAvatar;
    if (avatar != null) {
      final isInitials = RegExp(r'^[A-Z]{2}$').hasMatch(avatar);
      if (isInitials) {
        _selectedAvatar = avatar;
        _selectedAvatarPath = null;
      } else {
        // Check if it's a valid file path
        final file = File(avatar);
        if (file.existsSync()) {
          _selectedAvatarPath = avatar;
          _selectedAvatar = null;
        } else {
          _selectedAvatar = sampleInitials[0];
          _selectedAvatarPath = null;
        }
      }
    } else {
      _selectedAvatar = sampleInitials[0];
      _selectedAvatarPath = null;
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String appFolder = '${directory.path}/SmartPatient';
        final Directory folder = Directory(appFolder);
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        
        final String fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String filePath = '$appFolder/$fileName';
        
        final File savedImage = await File(image.path).copy(filePath);
        
        setState(() {
          _selectedAvatarPath = savedImage.path;
          _selectedAvatar = null;
        });

        widget.onAvatarSelected(savedImage.path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar uploaded successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectInitials(String initials) {
    setState(() {
      _selectedAvatar = initials;
      _selectedAvatarPath = null;
    });
    widget.onAvatarSelected(initials);
    Navigator.pop(context);
  }

  void _removeAvatar() {
    setState(() {
      _selectedAvatar = null;
      _selectedAvatarPath = null;
    });
    widget.onAvatarSelected('');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Choose Your Avatar',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.primaryBlue,
              ),
            ),
          ),
          // Preview - FIXED to show image correctly
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _selectedAvatarPath != null
                        ? Colors.transparent
                        : (isDark ? Colors.grey.shade800 : AppColors.gray100),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryBlue,
                      width: 2,
                    ),
                    image: _selectedAvatarPath != null
                        ? DecorationImage(
                            image: FileImage(File(_selectedAvatarPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedAvatarPath == null && _selectedAvatar != null
                      ? Center(
                          child: Text(
                            _selectedAvatar!,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.black,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedAvatarPath != null ? 'Custom Photo' : 'Selected',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.gray700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Photo',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOptionButton(
                          icon: Icons.photo_library,
                          label: 'Choose from Gallery',
                          color: AppColors.primaryBlue,
                          onTap: _pickImage,
                          isLoading: _isLoading,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Generate Initials Avatar',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a color combination for your initials',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(
                      initialColors.length,
                      (index) {
                        final color = initialColors[index];
                        final initials = sampleInitials[index % sampleInitials.length];
                        final isSelected = _selectedAvatar == initials &&
                            _selectedAvatarPath == null;
                        
                        return GestureDetector(
                          onTap: _isLoading ? null : () => _selectInitials(initials),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: AppColors.primaryBlue, width: 3)
                                  : Border.all(
                                      color: isDark ? Colors.grey.shade700 : Colors.white,
                                      width: 2,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: isDark ? 0.3 : 0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _removeAvatar,
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      label: Text(
                        'Remove Avatar',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.error.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey[200]!,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.gray700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isLoading,
    required bool isDark,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}