import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/features/security/lock_service.dart';

class LockEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => LockService.instance.isLockEnabled;

  Future<void> setEnabled(bool value) async {
    await LockService.instance.setLockEnabled(value);
    state = AsyncData(value);
  }
}

final lockEnabledProvider = AsyncNotifierProvider<LockEnabledNotifier, bool>(
  LockEnabledNotifier.new,
);
