import 'package:aios/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManagementScreen extends StatefulWidget {
  const PermissionManagementScreen({super.key});

  @override
  State<PermissionManagementScreen> createState() =>
      _PermissionManagementScreenState();
}

class _PermissionManagementScreenState
    extends State<PermissionManagementScreen> {
  final Map<String, bool> _statuses = {};

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final results = <String, bool>{};
    results['storage'] =
        await Permission.manageExternalStorage.status.isGranted;
    results['notifications'] = await Permission.notification.status.isGranted;
    results['contacts'] = await Permission.contacts.status.isGranted;
    results['phone'] = await Permission.phone.status.isGranted;
    results['sms'] = await Permission.sms.status.isGranted;
    if (mounted) setState(() => _statuses.addAll(results));
  }

  Future<void> _requestPermission(String key, Permission permission) async {
    await permission.request();
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final grantedCount = _statuses.values.where((v) => v).length;
    final totalCount = _statuses.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Permissions'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (totalCount > 0 && grantedCount == totalCount)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: const BorderSide(color: AppColors.success),
                ),
                child: const ListTile(
                  leading:
                      Icon(Icons.check_circle, color: AppColors.success),
                  title: Text(
                    'All permissions granted',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Grant permissions for full app functionality ($grantedCount/$totalCount)',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          _PermissionTile(
            icon: Icons.folder,
            title: 'Storage',
            description: 'Access model files and app data',
            granted: _statuses['storage'] ?? false,
            onRequest: () => _requestPermission(
              'storage',
              Permission.manageExternalStorage,
            ),
          ),
          _PermissionTile(
            icon: Icons.notifications,
            title: 'Notifications',
            description: 'Send notification alerts',
            granted: _statuses['notifications'] ?? false,
            onRequest: () => _requestPermission(
              'notifications',
              Permission.notification,
            ),
          ),
          _PermissionTile(
            icon: Icons.contacts,
            title: 'Contacts',
            description: 'Search and read contacts',
            granted: _statuses['contacts'] ?? false,
            onRequest: () => _requestPermission(
              'contacts',
              Permission.contacts,
            ),
          ),
          _PermissionTile(
            icon: Icons.phone,
            title: 'Phone',
            description: 'Make phone calls',
            granted: _statuses['phone'] ?? false,
            onRequest: () => _requestPermission(
              'phone',
              Permission.phone,
            ),
          ),
          _PermissionTile(
            icon: Icons.sms,
            title: 'SMS',
            description: 'Send SMS messages',
            granted: _statuses['sms'] ?? false,
            onRequest: () => _requestPermission(
              'sms',
              Permission.sms,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: granted ? AppColors.success.withValues(alpha: 0.3) : AppColors.divider,
          ),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: granted ? AppColors.success : AppColors.textSecondary,
            size: 20,
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          trailing: granted
              ? const Icon(Icons.check_circle,
                  color: AppColors.success, size: 18)
              : TextButton(
                  onPressed: onRequest,
                  child: const Text('Grant'),
                ),
        ),
      ),
    );
  }
}
