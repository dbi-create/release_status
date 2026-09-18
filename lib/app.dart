import 'dart:async';

import 'package:flutter/material.dart';

import 'package:release_status/cloud/attach_catalog.dart';
import 'package:release_status/cloud/cloud_config.dart';
import 'package:release_status/cloud/cloud_session.dart';
import 'package:release_status/cloud/cloud_session_scope.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/listing_url_verifier.dart';
import 'package:release_status/monitoring/monitoring_scheduler.dart';
import 'package:release_status/monitoring/production_monitor.dart';
import 'package:release_status/monitoring/request_policy.dart';
import 'package:release_status/monitoring/scheduled_check.dart';
import 'package:release_status/screens/dashboard_screen.dart';
import 'package:release_status/screens/login_screen.dart';
import 'package:release_status/screens/settings_screen.dart';
import 'package:release_status/screens/splash_screen.dart';
import 'package:release_status/notifications/live_alert_service.dart';
import 'package:release_status/screens/title_detail_screen.dart';
import 'package:release_status/screens/title_form_screen.dart';
import 'package:release_status/screens/titles_screen.dart';
import 'package:release_status/state/listing_url_scope.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_store.dart';
import 'package:release_status/widgets/app_sidebar.dart';
import 'package:release_status/widgets/app_wordmark.dart';
import 'package:release_status/widgets/catalog_header_actions.dart';

const Color _background = Color(0xFF101214);
const Color _surface = Color(0xFF1A1D23);
const Color _surfaceHighest = Color(0xFF242830);
const Color _primaryText = Color(0xFFF4F5F7);
const Color _secondaryText = Color(0xFF9AA0A6);
const Color _outline = Color(0xFF2C313A);
const Color _accent = Color(0xFF4A7FB5);

const double _wideLayoutBreakpoint = 960;

class ReleaseStatusApp extends StatefulWidget {
  const ReleaseStatusApp({
    super.key,
    this.availabilityMonitor,
    this.listingUrlChecker,
    this.catalogStore,
    this.initialSnapshot,
    this.initialTitles,
    this.enableScheduledMonitoring = false,
    this.showBootSplash = false,
  });

  final AvailabilityMonitor? availabilityMonitor;
  final ListingUrlChecker? listingUrlChecker;
  final CatalogStore? catalogStore;
  final CatalogSnapshot? initialSnapshot;
  final List<ReleaseTitle>? initialTitles;
  final bool enableScheduledMonitoring;
  final bool showBootSplash;

  @override
  State<ReleaseStatusApp> createState() => _ReleaseStatusAppState();
}

class _ReleaseStatusAppState extends State<ReleaseStatusApp> {
  late final TitleCatalog _catalog = TitleCatalog(
    store: widget.catalogStore,
    initialSnapshot: widget.initialSnapshot,
    initialTitles: widget.initialTitles,
    requestPolicy: widget.catalogStore == null
        ? MonitoringRequestPolicy.immediate
        : MonitoringRequestPolicy.standard,
  )..onTitlesWentLive = LiveAlertService.instance.handle;
  late final CloudSession _cloudSession = CloudSession()
    ..attachClient(releaseStatusCloudClient());
  late final AvailabilityMonitor _monitor =
      widget.availabilityMonitor ?? createProductionAvailabilityMonitor();
  MonitoringScheduler? _scheduler;
  Timer? _splashTimer;
  String? _boundUserId;
  late bool _showingSplash = widget.showBootSplash;

  @override
  void initState() {
    super.initState();
    if (widget.enableScheduledMonitoring) {
      _scheduler = MonitoringScheduler(onTick: _runScheduledCheck)..start();
    }
    _cloudSession.addListener(_bindCatalogToAccount);
    unawaited(_bindCatalogToAccount());
    if (widget.showBootSplash) {
      _splashTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) {
          return;
        }
        setState(() => _showingSplash = false);
        if (widget.enableScheduledMonitoring) {
          unawaited(_prepareLiveAlerts());
        }
      });
    } else if (widget.enableScheduledMonitoring) {
      unawaited(_prepareLiveAlerts());
    }
  }

  Future<void> _prepareLiveAlerts() async {
    await LiveAlertService.instance.ensureReady();
    await LiveAlertService.instance.listenForAccount(_cloudSession.userId);
  }

  Future<void> _bindCatalogToAccount() async {
    final userId = _cloudSession.userId;
    if (userId == _boundUserId) {
      return;
    }
    _boundUserId = userId;
    if (userId == null) {
      await _catalog.cloudSync?.stopWatching();
      _catalog.cloudSync = null;
      unawaited(LiveAlertService.instance.listenForAccount(null));
      return;
    }
    await attachSignedInCatalog(_catalog);
    unawaited(LiveAlertService.instance.listenForAccount(userId));
    unawaited(() async {
      try {
        await registerCurrentDeviceToken();
      } on Object {
        // Duplicate device tokens are expected on repeat sign-in.
      }
    }());
  }

  Future<void> _runScheduledCheck() async {
    await _catalog.syncFromCloud();
    if (!scheduledCheckShouldRun(
      settings: _catalog.settings,
      monitorConfigured: _monitor.isConfigured,
      hasTitles: _catalog.titles.isNotEmpty,
      isChecking: _catalog.isChecking,
    )) {
      return;
    }
    await _catalog.checkAllTitles(_monitor);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _scheduler?.dispose();
    _cloudSession
      ..removeListener(_bindCatalogToAccount)
      ..dispose();
    _catalog.dispose();
    super.dispose();
  }

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

    return AvailabilityMonitorScope(
      monitor: _monitor,
      child: ListingUrlCheckerScope(
        checker: widget.listingUrlChecker ?? fetchAndVerifyListingUrl,
        child: CloudSessionScope(
          session: _cloudSession,
          child: TitleCatalogScope(
          catalog: _catalog,
          child: MaterialApp(
          title: 'ReleaseStatus',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: colorScheme,
            scaffoldBackgroundColor: _background,
            textTheme: ThemeData(brightness: Brightness.dark).textTheme.apply(
              bodyColor: _primaryText,
              displayColor: _primaryText,
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: _surface,
              hintStyle: const TextStyle(color: _secondaryText),
              labelStyle: const TextStyle(color: _primaryText),
              floatingLabelStyle: const TextStyle(
                color: _primaryText,
                fontWeight: FontWeight.w600,
              ),
              helperStyle: const TextStyle(color: _secondaryText),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _accent, width: 1.4),
              ),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _surface),
          ),
          home: ListenableBuilder(
            listenable: _cloudSession,
            builder: (context, _) {
              if (_showingSplash) {
                return const SplashScreen();
              }
              if (CloudConfig.isConfigured && !_cloudSession.isSignedIn) {
                return LoginScreen(
                  onAuthenticated: () => attachSignedInCatalog(_catalog),
                );
              }
              return const AppShell();
            },
          ),
        ),
        ),
        ),
      ),
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
  int _bottomIndex = 0;
  final GlobalKey<NavigatorState> _dashboardNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _titlesNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _settingsNavigatorKey =
      GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState> get _currentNavigatorKey {
    switch (_selectedIndex) {
      case 0:
        return _dashboardNavigatorKey;
      case 1:
        return _titlesNavigatorKey;
      default:
        return _settingsNavigatorKey;
    }
  }

  void _onSelect(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = index;
      if (index < 2) {
        _bottomIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;
    final catalog = TitleCatalogScope.of(context);
    final monitor = AvailabilityMonitorScope.of(context);
    final headerActions = CatalogHeaderActions(
      checking: catalog.isChecking,
      canCheck: catalog.titles.isNotEmpty && !catalog.isChecking,
      notificationCount: catalog.attention.notificationCount,
      onCheckAll: () => catalog.checkAllTitles(monitor),
      onNotifications: () => openCatalogNotifications(
        context,
        onOpenTitle: _openTitle,
        catalog: catalog,
      ),
      onSettings: isWide ? null : () => _onSelect(2),
    );

    final content = Navigator(
      key: _currentNavigatorKey,
      onGenerateRoute: (_) {
        return MaterialPageRoute<void>(
          builder: (context) {
            if (_selectedIndex == 0) {
              return DashboardScreen(
                onOpenTitle: _openTitle,
                onAddTitle: _openAddTitle,
                onOpenTitles: () => _onSelect(1),
              );
            }
            if (_selectedIndex == 1) {
              return TitlesScreen(
                onOpenTitle: _openTitle,
                onAddTitle: _openAddTitle,
              );
            }
            return const SettingsScreen();
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
              onAddTitle: _openAddTitle,
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: AppWordmark(trailing: headerActions),
            ),
            Expanded(child: content),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex < 2 ? _selectedIndex : _bottomIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            _openAddTitle();
            return;
          }
          _onSelect(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Your Titles',
          ),
          NavigationDestination(
            key: ValueKey<String>('add-title-button'),
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add Title',
          ),
        ],
      ),
    );
  }

  void _openTitle(ReleaseTitle title) {
    _currentNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => TitleDetailScreen(titleId: title.id),
      ),
    );
  }

  void _openAddTitle() {
    _currentNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (context) => const TitleFormScreen()),
    );
  }
}
