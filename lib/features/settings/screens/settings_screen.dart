import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/settings_providers.dart';
import 'manage_categories_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final backup = ref.watch(backupProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Appearance
          _SectionHeader('Appearance'),
          RadioListTile<ThemeMode>(
            title: const Text('System'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (v) =>
                ref.read(themeModeProvider.notifier).setMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (v) =>
                ref.read(themeModeProvider.notifier).setMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (v) =>
                ref.read(themeModeProvider.notifier).setMode(v!),
          ),
          const Divider(),

          // Library
          _SectionHeader('Library'),
          ListTile(
            leading: const Icon(Icons.label_outline_rounded),
            title: const Text('Manage categories'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ManageCategoriesScreen()),
            ),
          ),
          const Divider(),

          // Backup
          _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export backup'),
            subtitle: const Text('Share a JSON + zip of your library'),
            trailing: backup.phase == BackupPhase.working
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: backup.phase == BackupPhase.working
                ? null
                : () => ref.read(backupProvider.notifier).export(),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Import backup'),
            subtitle: const Text('Restore or merge from a previous export'),
            onTap: backup.phase == BackupPhase.working
                ? null
                : () => _showImportDialog(context, ref),
          ),
          if (backup.phase == BackupPhase.error)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                backup.errorMessage ?? 'Unknown error',
                style: const TextStyle(
                    color: AppColors.error, fontSize: 12),
              ),
            ),
          const Divider(),

          // About
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Book Tracker'),
            subtitle: const Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import backup'),
        content: const Text(
          'Choose how to handle conflicts with existing books:',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(backupProvider.notifier)
                  .importFromFile(replaceAll: false);
            },
            child: const Text('Merge'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              _confirmReplace(context, ref);
            },
            child: const Text('Replace all'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmReplace(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Replace all local data?'),
        content: const Text(
          'This will delete all your current books and categories, '
          'then restore from the backup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(backupProvider.notifier)
                  .importFromFile(replaceAll: true);
            },
            child: const Text('Replace all'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.1,
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
