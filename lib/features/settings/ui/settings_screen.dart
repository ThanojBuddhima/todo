import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/features/security/lock_service.dart';
import 'package:todo/features/security/providers/lock_providers.dart';
import 'package:todo/features/settings/providers/settings_providers.dart';
import 'package:todo/features/tasks/data/task_dao.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final lockAsync = ref.watch(lockEnabledProvider);
    final accentSeed = ref.watch(accentSeedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Appearance'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Theme'),
                  subtitle: const Text('Choose the app theme'),
                  trailing: DropdownButton<ThemeMode>(
                    value: mode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value != null) {
                        await ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(value);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Accent colour'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: accentSeeds.map((color) {
                        final selected =
                            color.toARGB32() == accentSeed.toARGB32();
                        return GestureDetector(
                          onTap: () => ref
                              .read(accentSeedProvider.notifier)
                              .setSeed(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 10),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('Notifications'),
          Card(child: _NotificationPermissionTile()),
          const SizedBox(height: 16),
          _SectionHeader('Security'),
          Card(
            child: Column(
              children: [
                lockAsync.when(
                  loading: () => const ListTile(
                    title: Text('App Lock'),
                    trailing: CircularProgressIndicator(),
                  ),
                  error: (err, st) => const ListTile(
                    title: Text('App Lock'),
                    subtitle: Text('Unavailable'),
                  ),
                  data: (enabled) => SwitchListTile(
                    title: const Text('App Lock'),
                    subtitle: const Text('Require PIN or biometrics to open'),
                    value: enabled,
                    onChanged: (v) => _onLockToggled(context, ref, v),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('Change PIN'),
                  onTap: () => _showPinSetup(context, ref, isChange: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.done_all_outlined),
                  title: const Text('Clear completed tasks'),
                  subtitle: const Text('Soft-deletes all completed tasks'),
                  onTap: () => _clearCompleted(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Purge deleted tasks'),
                  subtitle: const Text(
                    'Permanently removes soft-deleted tasks',
                  ),
                  onTap: () => _purgeDeleted(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.warning_amber_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Wipe all data',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text('Permanently deletes everything'),
                  onTap: () => _wipeAll(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('About'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.offline_bolt_outlined),
                  title: Text('Works fully offline'),
                  subtitle: Text(
                    'All data stays on your device. No internet required.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onLockToggled(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    if (enable) {
      final hasPin = await LockService.instance.hasPinSet;
      if (!hasPin) {
        if (!context.mounted) return;
        final set = await _showPinSetup(context, ref, isChange: false);
        if (!set) return;
      }
      await ref.read(lockEnabledProvider.notifier).setEnabled(true);
    } else {
      await ref.read(lockEnabledProvider.notifier).setEnabled(false);
    }
  }

  Future<bool> _showPinSetup(
    BuildContext context,
    WidgetRef ref, {
    required bool isChange,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PinSetupSheet(isChange: isChange),
    );
    return result == true;
  }

  Future<void> _clearCompleted(BuildContext context) async {
    final ok = await _confirm(
      context,
      'Clear completed tasks?',
      'All completed tasks will be soft-deleted. They can still be restored from deleted tasks.',
    );
    if (!ok) return;
    await TaskDao().clearCompleted();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Completed tasks cleared')));
    }
  }

  Future<void> _purgeDeleted(BuildContext context) async {
    final ok = await _confirm(
      context,
      'Purge deleted tasks?',
      'All soft-deleted tasks will be permanently removed. This cannot be undone.',
    );
    if (!ok) return;
    await TaskDao().purgeDeleted();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted tasks purged')));
    }
  }

  Future<void> _wipeAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => _WipeConfirmDialog(),
    );
    if (confirmed != 'WIPE') return;
    try {
      await ref.read(notificationServiceProvider).cancelAllReminders();
      await TaskDao().wipeAll();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete all data: $error')),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All data deleted')));
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _NotificationPermissionTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NotificationPermissionTile> createState() =>
      _NotificationPermissionTileState();
}

class _NotificationPermissionTileState
    extends ConsumerState<_NotificationPermissionTile> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final granted = await ref
        .read(notificationServiceProvider)
        .areNotificationsEnabled();
    if (mounted) setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final granted = _granted;
    return ListTile(
      leading: Icon(
        granted == true
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        color: granted == true ? cs.primary : cs.error,
      ),
      title: const Text('Notifications'),
      subtitle: Text(
        granted == null
            ? 'Checking…'
            : granted
            ? 'Enabled'
            : 'Disabled — tap to open settings',
      ),
      trailing: granted == false
          ? TextButton(
              onPressed: () async {
                await AppSettings.openAppSettings(
                  type: AppSettingsType.notification,
                );
                await Future.delayed(const Duration(milliseconds: 500));
                _check();
              },
              child: const Text('Enable'),
            )
          : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PinSetupSheet extends StatefulWidget {
  final bool isChange;
  const _PinSetupSheet({required this.isChange});

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _oldPinCtrl = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    _oldPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    if (widget.isChange) {
      final old = _oldPinCtrl.text.trim();
      final valid = await LockService.instance.verifyPin(old);
      if (!valid) {
        setState(() => _error = 'Current PIN is incorrect');
        return;
      }
    }
    await LockService.instance.setPin(pin);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isChange ? 'Change PIN' : 'Set PIN',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (widget.isChange) ...[
            TextField(
              controller: _oldPinCtrl,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _pinCtrl,
            decoration: const InputDecoration(
              labelText: 'New PIN',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            decoration: const InputDecoration(
              labelText: 'Confirm PIN',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}

class _WipeConfirmDialog extends StatefulWidget {
  @override
  State<_WipeConfirmDialog> createState() => _WipeConfirmDialogState();
}

class _WipeConfirmDialogState extends State<_WipeConfirmDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wipe all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This will permanently delete ALL tasks, subtasks, and activity history. Type WIPE to confirm.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: 'Type WIPE',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ctrl.text == 'WIPE'
              ? () => Navigator.pop(context, 'WIPE')
              : null,
          child: const Text('Wipe'),
        ),
      ],
    );
  }
}
