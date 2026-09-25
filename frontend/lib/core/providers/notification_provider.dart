import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final storage = StorageService();
  final localList = await storage.getLocalNotifications();
  
  try {
    final token = await storage.getAuthToken();
    if (token != null) {
      final result = await ApiService().request(
        method: 'GET',
        endpoint: '/notifications',
      );
      
      if (result['success'] == true) {
        final apiList = List<Map<String, dynamic>>.from(result['notifications'] ?? []);
        
        // Merge & deduplicate by ID
        final Map<String, Map<String, dynamic>> combined = {};
        for (var n in localList) {
          combined[n['id'].toString()] = n;
        }
        for (var n in apiList) {
          combined[n['id'].toString()] = n;
        }

        final merged = combined.values.toList();
        merged.sort((a, b) {
          final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        return merged;
      }
    }
  } catch (_) {}

  return localList;
});

// Provider for total unread notification count
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final list = await ref.watch(notificationsProvider.future);
  return list.where((n) => n['is_read'] == 0 || n['is_read'] == false).length;
});