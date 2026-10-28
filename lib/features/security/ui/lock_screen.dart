import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:todo/features/security/lock_service.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = StringBuffer();
  String _error = '';
  bool _loading = false;
  static const _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _tryBiometrics();
  }

  Future<void> _tryBiometrics() async {
    final canUse = await LockService.instance.canUseBiometrics;
    if (!canUse) return;
    final ok = await LockService.instance.authenticateWithBiometrics();
    if (ok && mounted) widget.onUnlocked();
  }

  void _onDigit(String d) {
    if (_pin.length >= _pinLength || _loading) return;
    setState(() {
      _pin.write(d);
      _error = '';
    });
    if (_pin.length == _pinLength) _submitPin();
  }

  void _onDelete() {
    if (_pin.isEmpty || _loading) return;
    setState(() {
      final s = _pin.toString();
      _pin.clear();
      _pin.write(s.substring(0, s.length - 1));
      _error = '';
    });
  }

  Future<void> _submitPin() async {
    setState(() => _loading = true);
    final ok = await LockService.instance.verifyPin(_pin.toString());
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _pin.clear();
        _error = 'Incorrect PIN. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pinStr = _pin.toString();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_outline, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text('Enter PIN', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < pinStr.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? cs.primary : Colors.transparent,
                    border: Border.all(color: cs.primary, width: 2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            if (_error.isNotEmpty)
              Text(_error, style: TextStyle(color: cs.error, fontSize: 13)),
            const SizedBox(height: 32),
            _Numpad(
              onDigit: _onDigit,
              onDelete: _onDelete,
              onBiometric: _tryBiometrics,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onBiometric;

  const _Numpad({
    required this.onDigit,
    required this.onDelete,
    required this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row
                .map((d) => _NumKey(label: d, onTap: () => onDigit(d)))
                .toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NumKey(icon: Icons.fingerprint, onTap: onBiometric),
            _NumKey(label: '0', onTap: () => onDigit('0')),
            _NumKey(icon: Icons.backspace_outlined, onTap: onDelete),
          ],
        ),
      ],
    );
  }
}

class _NumKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _NumKey({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHigh,
        ),
        alignment: Alignment.center,
        child: label != null
            ? Text(
                label!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              )
            : Icon(icon, size: 24, color: cs.onSurface),
      ),
    );
  }
}
