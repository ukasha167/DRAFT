import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode     = ref.watch(themeModeProvider);
    final nickname = ref.watch(nicknameProvider);
    final backup   = ref.watch(backupProvider);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final ink      = isDark ? AppColors.dkInk : AppColors.ink;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // ── Profile header ─────────────────────────────────────
            GestureDetector(
              onTap: () => _editNickname(context, ref, nickname),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hi, $nickname.',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(color: ink),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.muted),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'YOUR SHELF. YOUR SYSTEM.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 2,
                            color: AppColors.muted,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            Divider(color: isDark ? AppColors.dkDivide : AppColors.divide,
                height: 1),

            // ── System ────────────────────────────────────────────
            _Section('SYSTEM', context),
            _SubLabel('Appearance', context),
            ...[ThemeMode.system, ThemeMode.light, ThemeMode.dark].map((m) {
              final label = switch (m) {
                ThemeMode.system => 'System Default',
                ThemeMode.light  => 'Light Mode',
                ThemeMode.dark   => 'Dark Mode',
              };
              return RadioListTile<ThemeMode>(
                dense: true,
                title: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium),
                value: m,
                groupValue: mode,
                activeColor: ink,
                onChanged: (v) =>
                    ref.read(themeModeProvider.notifier).setMode(v!),
              );
            }),

            Divider(color: isDark ? AppColors.dkDivide : AppColors.divide,
                height: 1),

            // ── Data ──────────────────────────────────────────────
            _Section('DATA', context),
            ListTile(
              dense: true,
              leading: Icon(Icons.upload_outlined, color: ink),
              title: Text('Export Data',
                  style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text('Share a JSON + zip of your library',
                  style: Theme.of(context).textTheme.bodySmall),
              trailing: backup.phase == BackupPhase.working
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              onTap: backup.phase == BackupPhase.working ? null
                  : () => ref.read(backupProvider.notifier).export(),
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.download_outlined, color: ink),
              title: Text('Import Data',
                  style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text('Restore or merge from previous backup',
                  style: Theme.of(context).textTheme.bodySmall),
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              onTap: backup.phase == BackupPhase.working ? null
                  : () => _showImportDialog(context, ref),
            ),
            if (backup.phase == BackupPhase.error)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(backup.errorMessage ?? 'Unknown error',
                    style: const TextStyle(color: AppColors.blood, fontSize: 12,
                        fontFamily: 'Manrope')),
              ),

            Divider(color: isDark ? AppColors.dkDivide : AppColors.divide,
                height: 1),

            // ── About ─────────────────────────────────────────────
            _Section('ABOUT', context),
            ListTile(
              dense: true,
              title: Text('DRAFT.',
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text('Version 1.0',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.privacy_tip_outlined, color: ink),
              title: Text('Privacy Policy',
                  style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text('Terms, collection details, and your rights.',
                  style: Theme.of(context).textTheme.bodySmall),
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              onTap: () {}, // wire up URL launcher when ready
            ),
          ],
        ),
      ),
    );
  }

  void _editNickname(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current == 'Reader' ? '' : current);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your name',
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(nicknameProvider.notifier).set(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import backup',
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700)),
        content: const Text(
            'Merge adds missing books. Replace discards everything local.',
            style: TextStyle(fontFamily: 'Manrope')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(backupProvider.notifier).importFromFile(replaceAll: false);
            },
            child: const Text('Merge'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.blood),
            onPressed: () {
              Navigator.pop(context);
              _confirmReplace(context, ref);
            },
            child: const Text('Replace all'),
          ),
        ],
      ),
    );
  }

  void _confirmReplace(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Replace all data?',
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700)),
        content: const Text(
            'This deletes everything in your current library and replaces it with the backup. Cannot be undone.',
            style: TextStyle(fontFamily: 'Manrope')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.blood),
            onPressed: () {
              Navigator.pop(context);
              ref.read(backupProvider.notifier).importFromFile(replaceAll: true);
            },
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }
}

Widget _Section(String label, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: Text(label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            )),
  );
}

Widget _SubLabel(String label, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Text(label,
        style: Theme.of(context).textTheme.titleSmall),
  );
}
