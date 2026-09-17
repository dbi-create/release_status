import 'package:flutter/material.dart';

class CatalogHeaderActions extends StatelessWidget {
  const CatalogHeaderActions({
    super.key,
    required this.checking,
    required this.canCheck,
    required this.notificationCount,
    required this.onCheckAll,
    required this.onNotifications,
    this.onSettings,
  });

  final bool checking;
  final bool canCheck;
  final int notificationCount;
  final VoidCallback onCheckAll;
  final VoidCallback onNotifications;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(40, 40),
      padding: const EdgeInsets.all(8),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey<String>('check-all-titles-button'),
          tooltip: 'Check All Titles',
          style: buttonStyle,
          onPressed: canCheck ? onCheckAll : null,
          icon: checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 24),
        ),
        Badge(
          isLabelVisible: notificationCount > 0,
          label: Text('$notificationCount'),
          child: IconButton(
            key: const ValueKey<String>('notifications-button'),
            tooltip: 'Notifications',
            style: buttonStyle,
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_outlined, size: 24),
          ),
        ),
        if (onSettings != null)
          IconButton(
            key: const ValueKey<String>('settings-button'),
            tooltip: 'Settings',
            style: buttonStyle,
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, size: 24),
          ),
      ],
    );
  }
}
