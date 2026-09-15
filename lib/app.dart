import 'package:flutter/material.dart';

import 'package:release_status/models/release_title.dart';
import 'package:release_status/screens/dashboard_screen.dart';
import 'package:release_status/screens/title_detail_screen.dart';
import 'package:release_status/screens/titles_screen.dart';
import 'package:release_status/widgets/app_sidebar.dart';

const Color _background = Color(0xFF101214);
const Color _surface = Color(0xFF1A1D23);
const Color _surfaceHighest = Color(0xFF242830);
const Color _primaryText = Color(0xFFF4F5F7);
const Color _secondaryText = Color(0xFF9AA0A6);
const Color _outline = Color(0xFF2C313A);
const Color _accent = Color(0xFF4A7FB5);

const double _wideLayoutBreakpoint = 960;

class ReleaseStatusApp extends StatelessWidget {
  const ReleaseStatusApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.dark(
      primary: _accent,
      onPrimary: Colors.white,
      secondary: _accent,
      onSecondary: Colors.white,
      surface: _surface,
      onSurface: _primaryText,
      onSurfaceVariant: _secondaryText,
      surfaceContainerLowest: _background,
      surfaceContainerHighest: _surfaceHighest,
      outline: _outline,
      outlineVariant: _outline,
      error: Color(0xFFE05555),
    );

    return MaterialApp(
      title: 'ReleaseStatus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _background,
        textTheme: ThemeData(
          brightness: Brightness.dark,
        ).textTheme.apply(bodyColor: _primaryText, displayColor: _primaryText),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _primaryText,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _surface,
          indicatorColor: _surfaceHighest,
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? _primaryText : _secondaryText,
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: _surface),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _onSelect(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;

    final content = Navigator(
      key: ValueKey<int>(_selectedIndex),
      onGenerateRoute: (_) {
        return MaterialPageRoute<void>(
          builder: (context) {
            if (_selectedIndex == 0) {
              return DashboardScreen(
                onOpenTitle: (title) => _openTitle(context, title),
                onAddTitle: () => showDeferredAddTitleDialog(context),
              );
            }
            return TitlesScreen(
              onOpenTitle: (title) => _openTitle(context, title),
              onAddTitle: () => showDeferredAddTitleDialog(context),
            );
          },
        );
      },
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            AppSidebar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onSelect,
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outline,
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ReleaseStatus')),
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onSelect,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'My Titles',
          ),
        ],
      ),
    );
  }

  void _openTitle(BuildContext context, ReleaseTitle title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TitleDetailScreen(title: title),
      ),
    );
  }
}

Future<void> showDeferredAddTitleDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add Title'),
        content: const Text('Title setup will be added in a later milestone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
