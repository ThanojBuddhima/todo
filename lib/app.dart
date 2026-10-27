import 'package:animations/animations.dart';
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
      themeAnimationDuration: AppMotion.platformReduced ? Duration.zero : AppMotion.themeCrossFade,
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
  int _previousIndex = 0;

  static const pages = [HomeScreen(), HistoryScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    NotificationService.instance.setTaskTapHandler(_openTaskFromNotification);
  }

  @override
  void dispose() {
    NotificationService.instance.setTaskTapHandler(null);
    super.dispose();
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
      body: PageTransitionSwitcher(
        duration: AppMotion.duration(context, AppMotion.base),
        reverse: _index < _previousIndex,
        transitionBuilder: (child, animation, secondaryAnimation) => SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Colors.transparent,
          child: child,
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          _previousIndex = _index;
          _index = value;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
