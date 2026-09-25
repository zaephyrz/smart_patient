import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/notification_provider.dart';

class NotificationBadge extends ConsumerWidget {
  final Widget child;
  final bool showZero;

  const NotificationBadge({
    super.key,
    required this.child,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationCountProvider);
    
    return countAsync.when(
      data: (count) {
        if (count == 0 && !showZero) {
          return child;
        }
        return Badge(
          label: Text(count.toString()),
          backgroundColor: Colors.red,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          child: child,
        );
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }
}