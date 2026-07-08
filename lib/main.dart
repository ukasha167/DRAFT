import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'core/theme/app_theme.dart';
import 'data/local/database.dart';
import 'data/providers/repository_providers.dart';
import 'features/library/screens/home_screen.dart';
import 'features/settings/providers/settings_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  final db = AppDatabase();

  final docsDir = await getApplicationDocumentsDirectory();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        docsDirProvider.overrideWithValue(docsDir.path),
      ],
      child: const BookTrackerApp(),
    ),
  );
}

class BookTrackerApp extends ConsumerWidget {
  const BookTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Book Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
