import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class LockService {
  static final LockService instance = LockService._();
  LockService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const _keyHash = 'pin_hash';
  static const _keySalt = 'pin_salt';
  static const _keyEnabled = 'lock_enabled';

  final _auth = LocalAuthentication();

  Future<bool> get isLockEnabled async {
    final v = await _storage.read(key: _keyEnabled);
    return v == 'true';
  }

  Future<bool> get hasPinSet async {
    final hash = await _storage.read(key: _keyHash);
    return hash != null;
  }

  Future<bool> get canUseBiometrics async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck || isSupported;
  }

  Future<void> setLockEnabled(bool enabled) async {
    await _storage.write(key: _keyEnabled, value: enabled ? 'true' : 'false');
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _keySalt, value: salt);
    await _storage.write(key: _keyHash, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _keySalt);
    final storedHash = await _storage.read(key: _keyHash);
    if (salt == null || storedHash == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to unlock the app',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _keyHash);
    await _storage.delete(key: _keySalt);
    await _storage.write(key: _keyEnabled, value: 'false');
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final input = utf8.encode('$salt:$pin');
    return sha256.convert(input).toString();
  }
}
