import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/deep_link_service.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded successfully');
  } catch (e) {
    debugPrint('⚠️ Error loading .env file: $e');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('⚠️ Notification service not available: $e');
  }
    
  runApp(
    const ProviderScope(
      child: SmartPatientApp(),
    ),
  );
}

class SmartPatientApp extends ConsumerStatefulWidget {
  const SmartPatientApp({super.key});

  @override
  ConsumerState<SmartPatientApp> createState() => _SmartPatientAppState();
}

class _SmartPatientAppState extends ConsumerState<SmartPatientApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.init(context, ref);
    });
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Smart Patient',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}