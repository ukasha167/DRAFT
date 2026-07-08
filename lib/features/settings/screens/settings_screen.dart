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
    final ink      = isDark ? AppColors.dkInk   : AppColors.ink;
    final divide   = isDark ? AppColors.dkDivide : AppColors.divide;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ← SETTINGS header — matches LIBRARY/WISHLIST pattern ──
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, weight: 900, size: 28),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  Text('SETTINGS',
                      style: Theme.of(context).textTheme.displaySmall),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 48),
                children: [

                  // ── Profile ─────────────────────────────────────
                  _SettingsBox(
                    child: GestureDetector(
                      onTap: () => _editNickname(context, ref, nickname),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Hi, $nickname.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(color: ink),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.edit_outlined,
                                    size: 16, color: AppColors.muted),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'YOUR SHELF. YOUR SYSTEM.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── SYSTEM ──────────────────────────────────────
                  const _SectionDivider('SYSTEM'),
                  _SettingsBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                          child: Text('Appearance',
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        ...[ThemeMode.system, ThemeMode.light, ThemeMode.dark]
                            .map((m) => RadioListTile<ThemeMode>(
                                  dense: true,
                                  visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 20),
                                  title: Text(
                                    switch (m) {
                                      ThemeMode.system => 'System Default',
                                      ThemeMode.light  => 'Light Mode',
                                      ThemeMode.dark   => 'Dark Mode',
                                    },
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  value: m,
                                  groupValue: mode,
                                  activeColor: ink,
                                  onChanged: (v) =>
                                      ref.read(themeModeProvider.notifier).setMode(v!),
                                )),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── DATA ────────────────────────────────────────
                  const _SectionDivider('DATA'),
                  _SettingsBox(
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text('Export Data',
                              style: Theme.of(context).textTheme.bodyMedium),
                          subtitle: Text('Share a JSON + zip of your library',
                              style: Theme.of(context).textTheme.bodySmall),
                          trailing: backup.phase == BackupPhase.working
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.muted, size: 20),
                          onTap: backup.phase == BackupPhase.working
                              ? null
                              : () => ref.read(backupProvider.notifier).export(),
                        ),
                        Divider(color: divide, height: 1, indent: 20, endIndent: 20),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text('Import Data',
                              style: Theme.of(context).textTheme.bodyMedium),
                          subtitle: Text(
                              'Restore or merge from previous backup',
                              style: Theme.of(context).textTheme.bodySmall),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: AppColors.muted, size: 20),
                          onTap: backup.phase == BackupPhase.working
                              ? null
                              : () => _showImportDialog(context, ref),
                        ),
                      ],
                    ),
                  ),

                  if (backup.phase == BackupPhase.error)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        backup.errorMessage ?? 'Unknown error',
                        style: const TextStyle(
                          color: AppColors.blood, fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── ABOUT ───────────────────────────────────────
                  const _SectionDivider('ABOUT'),
                  _SettingsBox(
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text('DRAFT.',
                              style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text('Version 1.0',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        Divider(color: divide, height: 1, indent: 20, endIndent: 20),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text('Privacy Policy',
                              style: Theme.of(context).textTheme.bodyMedium),
                          subtitle: Text(
                              'Terms, collection details, and your rights.',
                              style: Theme.of(context).textTheme.bodySmall),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: AppColors.muted, size: 20),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editNickname(
      BuildContext context, WidgetRef ref, String current) {
    final ctrl =
        TextEditingController(text: current == 'Reader' ? '' : current);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your name',
            style: TextStyle(
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
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
            style: TextStyle(
                fontWeight: FontWeight.w700)),
        content: const Text(
            'Merge adds missing books and keeps local data.\n'
            'Replace discards everything local first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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
            style: TextButton.styleFrom(
                foregroundColor: AppColors.blood),
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
            style: TextStyle(
                fontWeight: FontWeight.w700)),
        content: const Text(
            'Deletes everything in your current library and replaces it '
            'with the backup. Cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.blood),
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(backupProvider.notifier)
                  .importFromFile(replaceAll: true);
            },
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }
}

class _SettingsBox extends StatelessWidget {
  final Widget child;
  const _SettingsBox({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.dkCream : AppColors.cream;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider(this.label);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.dkInk : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
