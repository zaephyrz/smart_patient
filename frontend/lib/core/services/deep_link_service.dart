import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('com.example.frontend/deeplink');
  static AppLinks? _appLinks;
  static bool _initialized = false;
  static StreamSubscription<Uri>? _linkSubscription;
  
  /// Initialize deep link handling
  static Future<void> init(BuildContext context, WidgetRef ref) async {
    if (_initialized) return;
    _initialized = true;
    
    try {
      // Initialize app_links
      _appLinks = AppLinks();
      
      // Get initial link (from app start)
      final Uri? initialLink = await _appLinks?.getInitialLink();
      if (initialLink != null && context.mounted) {
        _handleDeepLink(initialLink.toString(), context, ref);
      }
      
      // Alternative: Get initial link from Android intent (only on mobile)
      try {
        final String? initialLinkFromAndroid = await _channel.invokeMethod('getInitialDeepLink');
        if (initialLinkFromAndroid != null && initialLinkFromAndroid.isNotEmpty && context.mounted) {
          _handleDeepLink(initialLinkFromAndroid, context, ref);
        }
      } catch (e) {
        // This is expected on non-Android platforms
        debugPrint('Failed to get initial link from Android (expected on non-Android platforms): $e');
      }
      
      // Listen for deep links while app is running (in foreground)
      _linkSubscription = _appLinks?.uriLinkStream.listen(
        (Uri uri) {
          if (context.mounted) {
            _handleDeepLink(uri.toString(), context, ref);
          }
        },
        onError: (err) {
          debugPrint('Deep link error: $err');
        },
      );
      
      // Also listen for Android intents (only on mobile)
      try {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'onDeepLink') {
            final String link = call.arguments as String;
            if (context.mounted) {
              _handleDeepLink(link, context, ref);
            }
          }
          return null;
        });
      } catch (e) {
        // This is expected on non-Android platforms
        debugPrint('Failed to set method channel handler: $e');
      }
      
    } catch (e) {
      debugPrint('Failed to initialize deep links: $e');
    }
  }
  
  static void _handleDeepLink(String link, BuildContext context, WidgetRef ref) {
    debugPrint('Deep link received: $link');
    
    try {
      final uri = Uri.parse(link);
      
      // Check if it's a reset password link
      if (uri.path.contains('reset-password') || 
          uri.path.contains('/reset-password') ||
          uri.host == 'reset-password') {
        final token = uri.queryParameters['token'];
        final email = uri.queryParameters['email'] ?? '';
        
        if (token != null && token.isNotEmpty) {
          debugPrint('Reset password token: $token');
          
          // Navigate to Reset Password Screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pushNamed(
                context,
                '/reset-password',
                arguments: {
                  'token': token,
                  'email': email,
                },
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }
  
  /// Dispose method to clean up resources
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _appLinks = null;
    _initialized = false;
  }
}