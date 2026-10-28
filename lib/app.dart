import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/core/theme/motion.dart';
import 'package:todo/features/activity/ui/history_screen.dart';
import 'package:todo/features/security/lock_service.dart';
import 'package:todo/features/security/ui/lock_screen.dart';
import 'package:todo/features/reminders/notification_service.dart';
import 'package:todo/features/settings/providers/settings_providers.dart';
import 'package:todo/features/settings/ui/settings_screen.dart';
import 'package:todo/features/tasks/ui/home_screen.dart';
import 'package:todo/features/tasks/ui/task_detail_screen.dart';

class App extends ConsumerWidget {
  const App({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final seed = ref.watch(accentSeedProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Todo',
      theme: AppTheme.light(seed: seed),
      darkTheme: AppTheme.dark(seed: seed),
      themeMode: themeMode,
      // MaterialApp drives the theme swap through AnimatedTheme internally.
      themeAnimationDuration: AppMotion.platformReduced
          ? Duration.zero
          : AppMotion.themeCrossFade,
      themeAnimationCurve: AppMotion.emphasized,
      home: const LockGate(child: RootShell()),
    );
  }
}

class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _checked = false;
  DateTime? _backgroundedAt;
  static const _timeout = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLock() async {
    final enabled = await LockService.instance.isLockEnabled;
    final hasPin = await LockService.instance.hasPinSet;
    if (mounted) {
      setState(() {
        _locked = enabled && hasPin;
        _checked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg != null && DateTime.now().difference(bg) >= _timeout) {
        _recheckLock();
      }
      _backgroundedAt = null;
    }
  }

  Future<void> _recheckLock() async {
    final enabled = await LockService.instance.isLockEnabled;
    final hasPin = await LockService.instance.hasPinSet;
    if (mounted && enabled && hasPin) {
      setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();
    if (_locked) {
      return LockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return widget.child;
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  late final PageController _pageController = PageController(
    initialPage: _index,
  );

  static const pages = [HomeScreen(), HistoryScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    NotificationService.instance.setTaskTapHandler(_openTaskFromNotification);
  }

  @override
  void dispose() {
    NotificationService.instance.setTaskTapHandler(null);
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int value) {
    if (value == _index) return;
    setState(() => _index = value);
    if (AppMotion.reduced(context)) {
      _pageController.jumpToPage(value);
    } else {
      _pageController.animateToPage(
        value,
        duration: AppMotion.base,
        curve: AppMotion.standard,
      );
    }
  }

  void _openTaskFromNotification(String taskId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = App.navigatorKey.currentState;
      if (navigator == null) {
        throw StateError('The app navigator is not ready for a notification.');
      }
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => TaskDetailScreen(taskId: taskId),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A PageView so tabs can be swiped as well as tapped; the nav bar and the
      // page position stay in sync in both directions.
      body: PageView(
        controller: _pageController,
        onPageChanged: (value) => setState(() => _index = value),
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          // Light outlines when idle, the rounded weight when selected — the
          // rounded set matches the app's radii and keeps the bar quiet.
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
